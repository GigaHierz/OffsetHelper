// SPDX-FileCopyrightText: 2022 Toucan Labs
//
// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract OffsetHelperStorage is OwnableUpgradeable {
    // token symbol => token address
    mapping(string => address) public eligibleTokenAddresses;
    address public contractRegistryAddress =
        // 0x48E04110aa4691ec3E9493187e6e9A3dB613e6e4; // Alfajores
        0xa30589F50b9641dacCB98AA2B4A8F24739c5B007; // Celo
    address public dexRouterAddress =
        0x7D28570135A2B1930F331c507F65039D4937f66c; // Ubeswap
    // 0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506 // SushiSwap
    // user => (token => amount)
    mapping(address => mapping(address => uint256)) public balances;
    string public baseToken; // token that the exchange uses to swap to pool tokens e.g., NCTs
    string public baseERC20; // token to get needed ERC20 amountto swap
}
