// SPDX-FileCopyrightText: 2022 Toucan Labs
//
// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract OffsetHelperStorage is OwnableUpgradeable {
    // token symbol => token address
    mapping(address => address[]) public eligibleSwapPaths;
    mapping(string => address[]) public eligibleSwapPathsBySymbol;

    address public contractRegistryAddress =
        // 0x263fA1c180889b3a3f46330F32a4a23287E99FC9; // Polygon
        0x6739D490670B2710dc7E79bB12E455DE33EE1cb6; // Mumbai
    // 0x48E04110aa4691ec3E9493187e6e9A3dB613e6e4; // Alfajores
    // 0xa30589F50b9641dacCB98AA2B4A8F24739c5B007; // Celo
    address public dexRouterAddress =
        // 0x7D28570135A2B1930F331c507F65039D4937f66c; // Ubeswap- from explorer with NCT - molarRouter
        // 0xd9145CCE52D386f254917e481eB44e9943F39138; // Ubeswap - remix
        // 0xa730B463395f5ca07EcE5cefeccF7f45e1E2C9Bf; // Ubeswap - sdk
        // 0xE3D8bd6Aed4F159bc8000a9cD47CffDb95F96121; // Ubeswap - docs
        0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506; // SushiSwap

    // user => (token => amount)
    mapping(address => mapping(address => uint256)) public balances;
}
