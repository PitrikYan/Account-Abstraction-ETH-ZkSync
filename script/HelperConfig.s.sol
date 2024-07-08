//SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {EntryPoint} from "lib/account-abstraction/contracts/core/EntryPoint.sol";

contract HelperConfig is Script {
    error HelperConfig__InvalidChaindId();

    struct NetworkConfig {
        address entryPoint;
        address account;
    }

    uint256 constant ETH_SEPOLIA_CHAIN_ID = 11155111;
    uint256 constant ZKSYNC_SEPOLIA_CHAIN_ID = 300;
    uint256 constant LOCAL_CHAIN_ID = 31337;
    address constant BURNER_WALLET = 0x96F0C8933e969aA5777c160AB68342B69DfA9aA4; // our sepolia address
        //address constant FOUNDRY_DEFAULT_SENDER = 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38;
    address constant ANVIL_DEFAULT_SENDER = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    NetworkConfig public localNetworkConfig;
    mapping(uint256 chainId => NetworkConfig) private networkConfigs;

    constructor() {
        networkConfigs[ETH_SEPOLIA_CHAIN_ID] = getEthSepoliaConfig();
        networkConfigs[ZKSYNC_SEPOLIA_CHAIN_ID] = getZkSyncSepoliaConfig();
    }

    function getConfig() public returns (NetworkConfig memory) {
        return getConfigByChainId(block.chainid);
    }

    function getConfigByChainId(uint256 chainId) public returns (NetworkConfig memory) {
        if (chainId == LOCAL_CHAIN_ID) {
            return getOrCreateAnvilEthConfig();
        } else if (networkConfigs[chainId].account != address(0)) {
            return networkConfigs[chainId];
        } else {
            revert HelperConfig__InvalidChaindId();
        }
    }

    function getEthSepoliaConfig() public pure returns (NetworkConfig memory) {
        return NetworkConfig({entryPoint: 0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789, account: BURNER_WALLET});
    }

    function getZkSyncSepoliaConfig() public pure returns (NetworkConfig memory) {
        return NetworkConfig({entryPoint: address(0), account: BURNER_WALLET});
    }

    function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory) {
        // avoiding of contantly deploying new mocks
        if (localNetworkConfig.account != address(0)) {
            return localNetworkConfig;
        }
        // deploy mock of entrypoint..
        console2.log("Deploying mocks!");
        vm.startBroadcast(ANVIL_DEFAULT_SENDER);
        EntryPoint entryPointMock = new EntryPoint();
        vm.stopBroadcast();

        localNetworkConfig = NetworkConfig({entryPoint: address(entryPointMock), account: ANVIL_DEFAULT_SENDER});

        return localNetworkConfig;
    }

    function run() public {}
}
