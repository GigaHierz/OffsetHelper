//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

contract Swapper {
    using SafeERC20 for IERC20;

    address public dexRouterAddress;
    string public baseToken; // token that the exchange uses to swap to pool tokens (NCT)
    string public baseERC20; // token to get needed ERC20 amount
    mapping(string => address) public tokenAddresses;

    constructor(
        string[] memory _tokenSymbols,
        address[] memory _tokenAddresses,
        address _routerAddress,
        string memory _baseToken,
        string memory _baseERC20
    ) {
        uint256 i = 0;
        while (i < _tokenSymbols.length) {
            tokenAddresses[_tokenSymbols[i]] = _tokenAddresses[i];
            i += 1;
        }
        dexRouterAddress = _routerAddress;
        baseToken = _baseToken;
        baseERC20 = _baseERC20;
    }

    function calculateNeededETHAmount(
        address _toToken,
        uint256 _amount
    ) public view returns (uint256) {
        IUniswapV2Router02 router = IUniswapV2Router02(dexRouterAddress);

        address[] memory path = generatePath(
            tokenAddresses[baseERC20],
            _toToken
        );

        uint256[] memory amounts = router.getAmountsIn(_amount, path);
        return amounts[0];
    }

    function swap(address _toToken, uint256 _amount) public payable {
        IUniswapV2Router02 router = IUniswapV2Router02(dexRouterAddress);

        address[] memory path = generatePath(
            tokenAddresses[baseERC20],
            _toToken
        );

        uint256[] memory amounts = router.swapETHForExactTokens{
            value: msg.value
        }(_amount, path, address(this), block.timestamp);

        IERC20(_toToken).transfer(msg.sender, _amount);

        if (msg.value > amounts[0]) {
            uint256 leftoverETH = msg.value - amounts[0];
            (bool success, ) = msg.sender.call{value: leftoverETH}(
                new bytes(0)
            );

            require(success, "Failed to send surplus ETH back to user.");
        }
    }

    function generatePath(
        address _fromToken,
        address _toToken
    ) internal view returns (address[] memory) {
        if (_toToken == tokenAddresses[baseToken]) {
            address[] memory path = new address[](2);
            path[0] = _fromToken;
            path[1] = _toToken;
            return path;
        } else if (_toToken == tokenAddresses[baseERC20]) {
            address[] memory path = new address[](3);
            path[0] = _fromToken;
            path[1] = tokenAddresses[baseToken];
            path[2] = _toToken;
            return path;
        } else {
            address[] memory path = new address[](4);
            path[0] = _fromToken;
            path[1] = tokenAddresses[baseToken];
            path[2] = _toToken;
            return path;
        }
    }

    fallback() external payable {}

    receive() external payable {}
}
