// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {LpToken} from "../test/mocks/LpToken.sol";

contract HelperConfig is Script {
    error HelperConfig__InvalidChainId();

    struct NetworkConfig {
        LpToken eth_icefrog_lp;
        LpToken btc_icefrog_lp;
        address defaultAccount;
        uint256 deployerKey;
    }

    uint256 public constant SEPOLIA_CHAIN_ID = 11155111;
    uint256 public constant ANVIL_CHAIN_ID = 31337;

    uint256 public constant INITIAL_SUPPLY = 100000 ether;

    address public constant FOUNDRY_DEFAULT_SENDER =
        0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    //0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38;

    uint256 public constant DEFAULT_ANVIL_KEY =
        0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

    // mapping(uint256 chainId => NetworkConfig) public networkConfigs;

    NetworkConfig public localNetworkConfig;

    // function setConfig(
    //     uint256 chainId,
    //     NetworkConfig memory networkConfig
    // ) public {
    //     networkConfigs[chainId] = networkConfig;
    // }

    function getConfig(uint256 chainId) public returns (NetworkConfig memory) {
        if (chainId == SEPOLIA_CHAIN_ID) {
            return getSepoliaEthConfig();
        } else if (chainId == ANVIL_CHAIN_ID) {
            return getOrCreateAnvilEthConfig();
        } else {
            revert HelperConfig__InvalidChainId();
        }
    }

    function getSepoliaEthConfig() public returns (NetworkConfig memory) {
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
        LpToken eth_if_lpToken = new LpToken(INITIAL_SUPPLY);
        LpToken btc_if_lpToken = new LpToken(INITIAL_SUPPLY);
        vm.stopBroadcast();
        return
            NetworkConfig({
                eth_icefrog_lp: eth_if_lpToken,
                btc_icefrog_lp: btc_if_lpToken,
                defaultAccount: 0x92D53c4e934C5D798bae38C516f61d12F3106de0,
                deployerKey: vm.envUint("PRIVATE_KEY")
            });
    }

    function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory) {
        if (address(localNetworkConfig.eth_icefrog_lp) != address(0)) {
            return localNetworkConfig;
        }
        vm.startBroadcast(DEFAULT_ANVIL_KEY);
        LpToken eth_if_lpToken = new LpToken(INITIAL_SUPPLY);
        LpToken btc_if_lpToken = new LpToken(INITIAL_SUPPLY);
        vm.stopBroadcast();
        localNetworkConfig = NetworkConfig({
            eth_icefrog_lp: eth_if_lpToken,
            btc_icefrog_lp: btc_if_lpToken,
            defaultAccount: FOUNDRY_DEFAULT_SENDER,
            deployerKey: DEFAULT_ANVIL_KEY
        });
        return localNetworkConfig;
    }
}
