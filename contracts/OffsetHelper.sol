// SPDX-FileCopyrightText: 2022 Toucan Labs
// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "./OffsetHelperStorage.sol";
import "./interfaces/IToucanPoolToken.sol";
import "./interfaces/IToucanCarbonOffsets.sol";
import "./interfaces/IToucanContractRegistry.sol";

/**
 * @title Toucan Protocol Offset Helpers
 * @notice Helper functions that simplify the carbon offsetting (retirement)
 * process.
 *
 * Retiring carbon tokens requires multiple steps and interactions with
 * Toucan Protocol's main contracts:
 * 1. Obtain a Toucan pool token such as BCT or NCT (by performing a token
 *    swap on a DEX).
 * 2. Redeem the pool token for a TCO2 token.
 * 3. Retire the TCO2 token.
 *
 * These steps are combined in each of the following "auto offset" methods
 * implemented in `OffsetHelper` to allow a retirement within one transaction:
 * - `autoOffsetPoolToken()` if the user already owns a Toucan pool
 *   token such as BCT or NCT,
 * - `autoOffsetExactOutETH()` if the user would like to perform a retirement
 *   using native tokens e.g., MATIC, specifying the exact amount of TCO2s to retire,
 * - `autoOffsetExactInETH()` if the user would like to perform a retirement
 *   using native tokens, swapping all sent native tokens into TCO2s,
 * - `autoOffsetExactOutToken()` if the user would like to perform a retirement
 *   using an ERC20 token (USDC, WETH or WMATIC), specifying the exact amount
 *   of TCO2s to retire,
 * - `autoOffsetExactInToken()` if the user would like to perform a retirement
 *   using an ERC20 token (USDC, WETH or WMATIC), specifying the exact amount
 *   of token to swap into TCO2s.
 *
 * In these methods, "auto" refers to the fact that these methods use
 * `autoRedeem()` in order to automatically choose a TCO2 token corresponding
 * to the oldest tokenized carbon project in the specfified token pool.
 * There are no fees incurred by the user when using `autoRedeem()`, i.e., the
 * user receives 1 TCO2 token for each pool token (BCT/NCT) redeemed.
 *
 * There are two `view` helper functions `calculateNeededETHAmount()` and
 * `calculateNeededTokenAmount()` that should be called before using
 * `autoOffsetExactOutETH()` and `autoOffsetExactOutToken()`, to determine how
 * much native tokens e.g., MATIC, respectively how much of the ERC20 token must be sent to the
 * `OffsetHelper` contract in order to retire the specified amount of carbon.
 *
 * The two `view` helper functions `calculateExpectedPoolTokenForETH()` and
 * `calculateExpectedPoolTokenForToken()` can be used to calculate the
 * expected amount of TCO2s that will be offset using functions
 * `autoOffsetExactInETH()` and `autoOffsetExactInToken()`.
 */
contract OffsetHelper is OffsetHelperStorage {
    using SafeERC20 for IERC20;
    address[] poolAddresses;
    string[] tokenSymbolsForPaths;
    address[][] paths;

    /**
     * @notice Contract constructor. Should specify arrays of ERC20 symbols and
     * addresses that can used by the contract.
     *
     * @dev See `isEligible()` for a list of tokens that can be used in the
     * contract. These can be modified after deployment by the contract owner
     * using `setEligibleTokenAddress()` and `deleteEligibleTokenAddress()`.
     *
     * @param _poolAddresses A list of pool token addresses.
     * @param _tokenSymbolsForPaths An array of symbols of the token the user want to retire carbon credits for
     * @param _paths An array of arrays of addresses to describe the path needed to swap form the baseToken to the pool Token
     * to the provided token symbols.
     */
    constructor(
        address[] memory _poolAddresses,
        string[] memory _tokenSymbolsForPaths,
        address[][] memory _paths
    ) {
        poolAddresses = _poolAddresses;
        tokenSymbolsForPaths = _tokenSymbolsForPaths;
        paths = _paths;

        uint256 i = 0;
        uint256 eligibleSwapPathsBySymbolLen = _tokenSymbolsForPaths.length;
        while (i < eligibleSwapPathsBySymbolLen) {
            eligibleSwapPaths[_paths[i][0]] = _paths[i];
            eligibleSwapPathsBySymbol[_tokenSymbolsForPaths[i]] = _paths[i];
            i += 1;
        }
    }

    /**
     * @notice Emitted upon successful redemption of TCO2 tokens from a Toucan
     * pool token such as BCT or NCT.
     *
     * @param sender The sender of the transaction
     * @param poolToken The address of the Toucan pool token used in the
     * redemption, for example, NCT or BCT
     * @param tco2s An array of the TCO2 addresses that were redeemed
     * @param amounts An array of the amounts of each TCO2 that were redeemed
     */
    event Redeemed(
        address sender,
        address poolToken,
        address[] tco2s,
        uint256[] amounts
    );

    modifier onlyRedeemable(address _token) {
        require(isRedeemable(_token), "Token not redeemable");

        _;
    }

    modifier onlySwappable(address _token) {
        require(isSwappable(_token), "Path doesn't yet exists.");

        _;
    }

    /**
     * @notice Retire carbon credits using the lowest quality (oldest) TCO2
     * tokens available from the specified Toucan token pool by sending ERC20
     * tokens (cUSD, USDC, WETH, WMATIC). Use `calculateNeededTokenAmount` first in
     * order to find out how much of the ERC20 token is required to retire the
     * specified quantity of TCO2.
     *
     * This function:
     * 1. Swaps the ERC20 token sent to the contract for the specified pool token.
     * 2. Redeems the pool token for the poorest quality TCO2 tokens available.
     * 3. Retires the TCO2 tokens.
     *
     * Note: The client must approve the ERC20 token that is sent to the contract.
     *
     * @dev When automatically redeeming pool tokens for the lowest quality
     * TCO2s there are no fees and you receive exactly 1 TCO2 token for 1 pool
     * token.
     *
     * @param _fromToken The address of the ERC20 token that the user sends
     * (e.g., cUSD, cUSD, USDC, WETH, WMATIC)
     * @param _poolToken The address of the Toucan pool token that the
     * user wants to use, for example, NCT or BCT
     * @param _amountToOffset The amount of TCO2 to offset
     *
     * @return tco2s An array of the TCO2 addresses that were redeemed
     * @return amounts An array of the amounts of each TCO2 that were redeemed
     */
    function autoOffsetExactOutToken(
        address _fromToken,
        address _poolToken,
        uint256 _amountToOffset
    ) public returns (address[] memory tco2s, uint256[] memory amounts) {
        // swap input token for BCT / NCT
        swapExactOutToken(_fromToken, _poolToken, _amountToOffset);

        // redeem BCT / NCT for TCO2s
        (tco2s, amounts) = autoRedeem(_poolToken, _amountToOffset);

        // retire the TCO2s to achieve offset
        autoRetire(tco2s, amounts);
    }

    /**
     * @notice Retire carbon credits using the lowest quality (oldest) TCO2
     * tokens available from the specified Toucan token pool by sending ERC20
     * tokens (cUSD, USDC, WETH, WMATIC). All provided token is consumed for
     * offsetting.
     *
     * This function:
     * 1. Swaps the ERC20 token sent to the contract for the specified pool token.
     * 2. Redeems the pool token for the poorest quality TCO2 tokens available.
     * 3. Retires the TCO2 tokens.
     *
     * Note: The client must approve the ERC20 token that is sent to the contract.
     *
     * @dev When automatically redeeming pool tokens for the lowest quality
     * TCO2s there are no fees and you receive exactly 1 TCO2 token for 1 pool
     * token.
     *
     * @param _fromToken The address of the ERC20 token that the user sends
     * (e.g., cUSD, cUSD, USDC, WETH, WMATIC)
     * @param _poolToken The address of the Toucan pool token that the
     * user wants to use, for example, NCT or BCT
     * @param _amountToSwap The amount of ERC20 token to swap into Toucan pool
     * token. Full amount will be used for offsetting.
     *
     * @return tco2s An array of the TCO2 addresses that were redeemed
     * @return amounts An array of the amounts of each TCO2 that were redeemed
     */
    function autoOffsetExactInToken(
        address _fromToken,
        address _poolToken,
        uint256 _amountToSwap
    ) public returns (address[] memory tco2s, uint256[] memory amounts) {
        // swap input token for BCT / NCT
        uint256 amountToOffset = swapExactInToken(
            _fromToken,
            _poolToken,
            _amountToSwap
        );

        // redeem BCT / NCT for TCO2s
        (tco2s, amounts) = autoRedeem(_poolToken, amountToOffset);

        // retire the TCO2s to achieve offset
        autoRetire(tco2s, amounts);
    }

    /**
     * @notice Retire carbon credits using the lowest quality (oldest) TCO2
     * tokens available from the specified Toucan token pool by sending native tokens e.g., MATIC.
     * Use `calculateNeededETHAmount()` first in order to find out how much
     * native tokens are required to retire the specified quantity of TCO2.
     *
     * This function:
     * 1. Swaps the Matic sent to the contract for the specified pool token.
     * 2. Redeems the pool token for the poorest quality TCO2 tokens available.
     * 3. Retires the TCO2 tokens.
     *
     * @dev If the user sends too much native tokens , the leftover amount will be sent back
     * to the user.
     *
     * @param _fromToken The address of the native token that the user sends
     * @param _poolToken The address of the pool token to swap for,
     * for example, NCT or BCT
     * @param _amountToOffset The amount of TCO2 to offset.
     *
     * @return tco2s An array of the TCO2 addresses that were redeemed
     * @return amounts An array of the amounts of each TCO2 that were redeemed
     */
    function autoOffsetExactOutETH(
        address _fromToken,
        address _poolToken,
        uint256 _amountToOffset
    )
        public
        payable
        returns (address[] memory tco2s, uint256[] memory amounts)
    {
        // swap native tokens  for BCT / NCT
        swapExactOutETH(_fromToken, _poolToken, _amountToOffset);

        // redeem BCT / NCT for TCO2s
        (tco2s, amounts) = autoRedeem(_poolToken, _amountToOffset);

        // retire the TCO2s to achieve offset
        autoRetire(tco2s, amounts);
    }

    /**
     * @notice Retire carbon credits using the lowest quality (oldest) TCO2
     * tokens available from the specified Toucan token pool by sending native tokens e.g., MATIC.
     * All provided native tokens  is consumed for offsetting.
     *
     * This function:
     * 1. Swaps the Matic sent to the contract for the specified pool token.
     * 2. Redeems the pool token for the poorest quality TCO2 tokens available.
     * 3. Retires the TCO2 tokens.
     *
     * @param _fromToken Symbol of the Native Token like e.g., WMATIC
     * @param _poolToken The address of the pool token to swap for,
     * for example, NCT or BCT
     *
     * @return tco2s An array of the TCO2 addresses that were redeemed
     * @return amounts An array of the amounts of each TCO2 that were redeemed
     */
    function autoOffsetExactInETH(
        address _fromToken,
        address _poolToken
    )
        public
        payable
        returns (address[] memory tco2s, uint256[] memory amounts)
    {
        // swap native tokens  for BCT / NCT
        uint256 amountToOffset = swapExactInETH(_fromToken, _poolToken);

        // redeem BCT / NCT for TCO2s
        (tco2s, amounts) = autoRedeem(_poolToken, amountToOffset);

        // retire the TCO2s to achieve offset
        autoRetire(tco2s, amounts);
    }

    /**
     * @notice Retire carbon credits using the lowest quality (oldest) TCO2
     * tokens available by sending Toucan pool tokens, for example, BCT or NCT.
     *
     * This function:
     * 1. Redeems the pool token for the poorest quality TCO2 tokens available.
     * 2. Retires the TCO2 tokens.
     *
     * Note: The client must approve the pool token that is sent.
     *
     * @param _poolToken The address of the pool token to swap for,
     * for example, NCT or BCT
     * @param _amountToOffset The amount of TCO2 to offset.
     *
     * @return tco2s An array of the TCO2 addresses that were redeemed
     * @return amounts An array of the amounts of each TCO2 that were redeemed
     */
    function autoOffsetPoolToken(
        address _poolToken,
        uint256 _amountToOffset
    ) public returns (address[] memory tco2s, uint256[] memory amounts) {
        // deposit pool token from user to this contract
        deposit(_poolToken, _amountToOffset);

        // redeem BCT / NCT for TCO2s
        (tco2s, amounts) = autoRedeem(_poolToken, _amountToOffset);

        // retire the TCO2s to achieve offset
        autoRetire(tco2s, amounts);
    }

    /**
     * @notice Checks whether an address is a Toucan pool token address
     * @param _erc20Address address of token to be checked
     * @return True if the address is a Toucan pool token address
     */
    function isRedeemable(address _erc20Address) private view returns (bool) {
        for (uint i = 0; i < poolAddresses.length; i++) {
            if (poolAddresses[i] == _erc20Address) {
                return true;
            }
        }

        return false;
    }

    /**
     * @notice Checks whether an address can be used in a token swap
     * @param _erc20Address address of token to be checked
     * @return True if the specified address can be used in a swap
     */
    function isSwappable(address _erc20Address) private view returns (bool) {
        for (uint i = 0; i < paths.length; i++) {
            if (paths[i][0] == _erc20Address) {
                return true;
            }
        }

        return false;
    }

    /**
     * @notice Return how much of the specified ERC20 token is required in
     * order to swap for the desired amount of a Toucan pool token, for
     * example, BCT or NCT.
     *
     * @param _fromToken The address of the ERC20 token used for the swap
     * @param _poolToken The address of the pool token to swap for,
     * for example, NCT or BCT
     * @param _toAmount The desired amount of pool token to receive
     * @return amountsIn The amount of the ERC20 token required in order to
     * swap for the specified amount of the pool token
     */
    function calculateNeededTokenAmount(
        address _fromToken,
        address _poolToken,
        uint256 _toAmount
    )
        public
        view
        onlySwappable(_fromToken)
        onlyRedeemable(_poolToken)
        returns (uint256)
    {
        uint256[] memory amounts = calculateExactOutSwap(
            _fromToken,
            _poolToken,
            _toAmount
        );
        return amounts[0];
    }

    /**
     * @notice Calculates the expected amount of Toucan Pool token that can be
     * acquired by swapping the provided amount of ERC20 token.
     *
     * @param _fromToken The address of the ERC20 token used for the swap
     * @param _poolToken The address of the pool token to swap for,
     * for example, NCT or BCT
     * @param _fromAmount The amount of ERC20 token to swap
     * @return The expected amount of Pool token that can be acquired
     */
    function calculateExpectedPoolTokenForToken(
        address _fromToken,
        address _poolToken,
        uint256 _fromAmount
    )
        public
        view
        onlySwappable(_fromToken)
        onlyRedeemable(_poolToken)
        returns (uint256)
    {
        uint256[] memory amounts = calculateExactInSwap(
            _fromToken,
            _poolToken,
            _fromAmount
        );
        return amounts[amounts.length - 1];
    }

    /**
     * @notice Swap eligible ERC20 tokens for Toucan pool tokens (BCT/NCT) on SushiSwap
     * @dev Needs to be approved on the client side
     * @param _fromToken The address of the ERC20 token used for the swap
     * @param _poolToken The address of the pool token to swap for,
     * for example, NCT or BCT
     * @param _toAmount The required amount of the Toucan pool token (NCT/BCT)
     */
    function swapExactOutToken(
        address _fromToken,
        address _poolToken,
        uint256 _toAmount
    ) public onlySwappable(_fromToken) onlyRedeemable(_poolToken) {
        // calculate path & amounts
        address[] memory path = generatePath(_fromToken, _poolToken);
        uint256[] memory expAmounts = calculateExactOutSwap(
            _fromToken,
            _poolToken,
            _toAmount
        );
        uint256 amountIn = expAmounts[0];

        // transfer tokens
        IERC20(_fromToken).safeTransferFrom(
            msg.sender,
            address(this),
            amountIn
        );

        // approve router
        IERC20(_fromToken).approve(dexRouterAddress, amountIn);

        // swap
        uint256[] memory amounts = dexRouter().swapTokensForExactTokens(
            _toAmount,
            amountIn, // max. input amount
            path,
            address(this),
            block.timestamp
        );

        // remove remaining approval if less input token was consumed
        if (amounts[0] < amountIn) {
            IERC20(_fromToken).approve(dexRouterAddress, 0);
        }

        // update balances
        balances[msg.sender][_poolToken] += _toAmount;
    }

    /**
     * @notice Swap eligible ERC20 tokens for Toucan pool tokens (BCT/NCT) on
     * SushiSwap. All provided ERC20 tokens will be swapped.
     * @dev Needs to be approved on the client side.
     * @param _fromToken The address of the ERC20 token used for the swap
     * @param _poolToken The address of the pool token to swap for,
     * @param _fromAmount The amount of ERC20 token to swap
     * for example, NCT or BCT
     * @return Resulting amount of Toucan pool token that got acquired for the
     * swapped ERC20 tokens.
     */
    function swapExactInToken(
        address _fromToken,
        address _poolToken,
        uint256 _fromAmount
    )
        public
        onlySwappable(_fromToken)
        onlyRedeemable(_poolToken)
        returns (uint256)
    {
        // calculate path & amounts

        address[] memory path = generatePath(_fromToken, _poolToken);

        uint256 len = path.length;

        // transfer tokens
        IERC20(_fromToken).safeTransferFrom(
            msg.sender,
            address(this),
            _fromAmount
        );

        // approve router
        IERC20(_fromToken).safeApprove(dexRouterAddress, _fromAmount);

        // swap
        uint256[] memory amounts = dexRouter().swapExactTokensForTokens(
            _fromAmount,
            0, // min. output amount
            path,
            address(this),
            block.timestamp
        );
        uint256 amountOut = amounts[len - 1];

        // update balances
        balances[msg.sender][_poolToken] += amountOut;

        return amountOut;
    }

    // apparently I need a fallback and a receive method to fix the situation where transfering dust native tokens
    // in the native tokens  to token swap fails
    fallback() external payable {}

    receive() external payable {}

    /**
     * @notice Return how much native tokens e.g, MATIC is required in order to swap for the
     * desired amount of a Toucan pool token, for example, BCT or NCT.
     *
     * @param _poolToken The address of the pool token to swap for, for
     * example, NCT or BCT
     * @param _toAmount The desired amount of pool token to receive
     * @return amounts The amount of native tokens  required in order to swap for
     * the specified amount of the pool token
     */
    function calculateNeededETHAmount(
        address _fromToken,
        address _poolToken,
        uint256 _toAmount
    ) public view onlyRedeemable(_poolToken) returns (uint256) {
        uint256[] memory amounts = calculateExactOutSwap(
            _fromToken,
            _poolToken,
            _toAmount
        );
        return amounts[0];
    }

    /**
     * @notice Calculates the expected amount of Toucan Pool token that can be
     * acquired by swapping the provided amount of native tokens e.g., MATIC.
     *
     * @param _fromToken Native Token like e.g., MATIC
     * @param _fromTokenAmount The amount of native tokens  to swap
     * @param _poolToken The address of the pool token to swap for,
     * for example, NCT or BCT
     * @return The expected amount of Pool token that can be acquired
     */
    function calculateExpectedPoolTokenForETH(
        address _fromToken,
        address _poolToken,
        uint256 _fromTokenAmount
    ) public view onlyRedeemable(_poolToken) returns (uint256) {
        uint256[] memory amounts = calculateExactInSwap(
            _fromToken,
            _poolToken,
            _fromTokenAmount
        );
        return amounts[amounts.length - 1];
    }

    /**
     * @notice Swap native tokens e.g., MATIC for Toucan pool tokens (BCT/NCT) on SushiSwap.
     * Remaining native tokens  that was not consumed by the swap is returned.
     * @param _fromToken Native Token like e.g., CELO to swap
     * @param _poolToken The address of the pool token to swap for,
     * for example, NCT or BCT
     * @param _toAmount The required amount of the Toucan pool token (NCT/BCT)
     */
    function swapExactOutETH(
        address _fromToken,
        address _poolToken,
        uint256 _toAmount
    ) public payable onlyRedeemable(_poolToken) {
        // create path & amounts
        address[] memory path = generatePath(_fromToken, _poolToken);

        // swap
        uint256[] memory amounts = dexRouter().swapETHForExactTokens{
            value: msg.value
        }(_toAmount, path, address(this), block.timestamp);

        // send surplus back
        if (msg.value > amounts[0]) {
            uint256 leftoverETH = msg.value - amounts[0];
            (bool success, ) = msg.sender.call{value: leftoverETH}(
                new bytes(0)
            );

            require(success, "Failed to send surplus back");
        }

        // update balances
        balances[msg.sender][_poolToken] += _toAmount;
    }

    /**
     * @notice Swap native tokens e.g., MATIC for Toucan pool tokens (BCT/NCT) on SushiSwap. All
     * provided native tokens  will be swapped.
     * @param _fromToken Native Token like e.g., CELO to swap from will be swapped for pool token
     * @param _poolToken The address of the pool token to swap for,
     * for example, NCT or BCT
     * @return Resulting amount of Toucan pool token that got acquired for the
     * swapped native tokens .
     */
    function swapExactInETH(
        address _fromToken,
        address _poolToken
    ) public payable onlyRedeemable(_poolToken) returns (uint256) {
        // create path & amounts
        uint256 fromAmount = msg.value;
        address[] memory path = generatePath(_fromToken, _poolToken);

        uint256 len = path.length;

        // swap
        uint256[] memory amounts = dexRouter().swapExactETHForTokens{
            value: fromAmount
        }(0, path, address(this), block.timestamp);
        uint256 amountOut = amounts[len - 1];

        // update balances
        balances[msg.sender][_poolToken] += amountOut;

        return amountOut;
    }

    /**
     * @notice Allow users to withdraw tokens they have deposited.
     */
    function withdraw(address _erc20Addr, uint256 _amount) public {
        require(
            balances[msg.sender][_erc20Addr] >= _amount,
            "Insufficient balance"
        );

        IERC20(_erc20Addr).safeTransfer(msg.sender, _amount);
        balances[msg.sender][_erc20Addr] -= _amount;
    }

    /**
     * @notice Allow users to deposit BCT / NCT.
     * @dev Needs to be approved
     */
    function deposit(
        address _erc20Addr,
        uint256 _amount
    ) public onlyRedeemable(_erc20Addr) {
        IERC20(_erc20Addr).safeTransferFrom(msg.sender, address(this), _amount);
        balances[msg.sender][_erc20Addr] += _amount;
    }

    /**
     * @notice Redeems the specified amount of NCT / BCT for TCO2.
     * @dev Needs to be approved on the client side
     * @param _fromToken Could be the address of NCT or BCT
     * @param _amount Amount to redeem
     * @return tco2s An array of the TCO2 addresses that were redeemed
     * @return amounts An array of the amounts of each TCO2 that were redeemed
     */
    function autoRedeem(
        address _fromToken,
        uint256 _amount
    )
        public
        onlyRedeemable(_fromToken)
        returns (address[] memory tco2s, uint256[] memory amounts)
    {
        require(
            balances[msg.sender][_fromToken] >= _amount,
            "Insufficient NCT/BCT balance"
        );

        // instantiate pool token (NCT or BCT)
        IToucanPoolToken PoolTokenImplementation = IToucanPoolToken(_fromToken);

        // auto redeem pool token for TCO2; will transfer automatically picked TCO2 to this contract
        (tco2s, amounts) = PoolTokenImplementation.redeemAuto2(_amount);

        // update balances
        balances[msg.sender][_fromToken] -= _amount;
        uint256 tco2sLen = tco2s.length;
        for (uint256 index = 0; index < tco2sLen; index++) {
            balances[msg.sender][tco2s[index]] += amounts[index];
        }

        emit Redeemed(msg.sender, _fromToken, tco2s, amounts);
    }

    /**
     * @notice Retire the specified TCO2 tokens.
     * @param _tco2s The addresses of the TCO2s to retire
     * @param _amounts The amounts to retire from each of the corresponding
     * TCO2 addresses
     */
    function autoRetire(
        address[] memory _tco2s,
        uint256[] memory _amounts
    ) public {
        uint256 tco2sLen = _tco2s.length;
        require(tco2sLen != 0, "Array empty");

        require(tco2sLen == _amounts.length, "Arrays unequal");

        uint256 i = 0;
        while (i < tco2sLen) {
            if (_amounts[i] == 0) {
                unchecked {
                    i++;
                }
                continue;
            }
            require(
                balances[msg.sender][_tco2s[i]] >= _amounts[i],
                "Insufficient TCO2 balance"
            );

            balances[msg.sender][_tco2s[i]] -= _amounts[i];

            IToucanCarbonOffsets(_tco2s[i]).retire(_amounts[i]);

            unchecked {
                ++i;
            }
        }
    }

    function calculateExactOutSwap(
        address _fromToken,
        address _poolToken,
        uint256 _toAmount
    ) internal view returns (uint256[] memory amounts) {
        // create path & calculate amounts
        address[] memory path = generatePath(_fromToken, _poolToken);
        uint256 len = path.length;

        amounts = dexRouter().getAmountsIn(_toAmount, path);

        // sanity check arrays
        require(len == amounts.length, "Arrays unequal");
        require(_toAmount == amounts[len - 1], "Output amount mismatch");
    }

    function calculateExactInSwap(
        address _fromToken,
        address _poolToken,
        uint256 _fromAmount
    ) internal view returns (uint256[] memory amounts) {
        // create path & calculate amounts
        address[] memory path = generatePath(_fromToken, _poolToken);
        uint256 len = path.length;

        amounts = dexRouter().getAmountsOut(_fromAmount, path);

        // sanity check arrays
        require(len == amounts.length, "Arrays unequal");
        require(_fromAmount == amounts[0], "Input amount mismatch");
    }

    /**
     * @notice Show all tokens that can be used to Offset.
     * @param _tokens a list of token symbols that can be swapped for pool tokens
     */
    function showEligibleTokens()
        public
        view
        returns (string[] memory _tokens)
    {
        _tokens = tokenSymbolsForPaths;
    }

    /**
     * @notice Show all pool token addresses that can be used to retired.
     * @param _poolTokens a list of token symbols that can be retired.
     */
    function showEligiblePoolTokens()
        public
        view
        returns (address[] memory _poolTokens)
    {
        _poolTokens = poolAddresses;
    }

    /**
     * @notice Show all pool token addresses that can be used to retired.
     * @param _fromToken a list of token symbols that can be retired.
     * @param _toToken a list of token symbols that can be retired.
     */
    function generatePath(
        address _fromToken,
        address _toToken
    ) internal view returns (address[] memory path) {
        uint256 len = eligibleSwapPaths[_fromToken].length;
        if (len == 1) {
            path = new address[](2);
            path[0] = _fromToken;
            path[1] = _toToken;
            return path;
        }
        if (len == 2) {
            path = new address[](3);
            path[0] = _fromToken;
            path[1] = eligibleSwapPaths[_fromToken][1];
            path[2] = _toToken;
            return path;
        }
        if (len == 3) {
            path = new address[](3);
            path[0] = _fromToken;
            path[1] = eligibleSwapPaths[_fromToken][1];
            path[2] = eligibleSwapPaths[_fromToken][2];
            path[3] = _toToken;
            return path;
        } else {
            path = new address[](4);
            path[0] = _fromToken;
            path[1] = eligibleSwapPaths[_fromToken][1];
            path[2] = eligibleSwapPaths[_fromToken][2];
            path[3] = eligibleSwapPaths[_fromToken][3];
            path[4] = _toToken;
            return path;
        }
    }

    function dexRouter() internal view returns (IUniswapV2Router02) {
        return IUniswapV2Router02(dexRouterAddress);
    }

    // ----------------------------------------
    //  Admin methods
    // ----------------------------------------

    /**
     * @notice Change or add eligible paths and their addresses.
     * @param _tokenSymbol The symbol of the token to add
     * @param _path The path of the path to add
     */
    function addPath(
        string memory _tokenSymbol,
        address[] memory _path
    ) public virtual onlyOwner {
        eligibleSwapPaths[_path[0]] = _path;
        eligibleSwapPathsBySymbol[_tokenSymbol] = _path;
    }

    /**
     * @notice Delete eligible tokens stored in the contract.
     * @param _tokenSymbol The symbol of the path to remove
     */
    function removePath(string memory _tokenSymbol) public virtual onlyOwner {
        delete eligibleSwapPaths[eligibleSwapPathsBySymbol[_tokenSymbol][0]];
        delete eligibleSwapPathsBySymbol[_tokenSymbol];
    }

    /**
     * @notice Change or add pool token addresses.
     * @param _poolToken The address of the pool token to add
     */
    function addPoolToken(address _poolToken) public virtual onlyOwner {
        poolAddresses.push(_poolToken);
    }

    /**
     * @notice Delete eligible pool token addresses stored in the contract.
     * @param _poolToken The address of the pool token to remove
     */
    function removePoolToken(address _poolToken) public virtual onlyOwner {
        for (uint256 i; i < poolAddresses.length; i++) {
            if (poolAddresses[i] == _poolToken) {
                poolAddresses[i] = poolAddresses[poolAddresses.length - 1];
                poolAddresses.pop();
                break;
            }
        }
    }

    /**
     * @notice Change the TCO2 contracts registry.
     * @param _address The address of the Toucan contract registry to use
     */
    function setToucanContractRegistry(
        address _address
    ) public virtual onlyOwner {
        contractRegistryAddress = _address;
    }
}
