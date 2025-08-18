// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {IceFrog} from "../src/IceFrog.sol";
import {Airdrop} from "../src/Airdrop.sol";
import {StakingMining} from "../src/StakingMining.sol";
import {SalesFactory} from "../src/sale/SalesFactory.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract Deploy is Script {
    uint256 public constant INITIAL_SUPPLY = 100000 ether;

    uint256 public constant REWARD_PER_SECOND = 1 ether;

    uint256 public constant START_TIMESTAMP_DELTA = 600 seconds;

    // uint256 public constant DEFAULT_ANVIL_KEY =
    //     0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

    function run()
        external
        returns (IceFrog, Airdrop, SalesFactory, address, HelperConfig)
    {
        HelperConfig helperConfig = new HelperConfig();

        HelperConfig.NetworkConfig memory config = helperConfig.getConfig(
            block.chainid
        );

        vm.startBroadcast(config.defaultAccount);

        IceFrog iceFrog = new IceFrog(INITIAL_SUPPLY);

        Airdrop airdrop = new Airdrop(address(iceFrog));

        StakingMining stakingMining = new StakingMining();

        ERC1967Proxy proxy = new ERC1967Proxy(address(stakingMining), "");

        SalesFactory salesFactory = new SalesFactory(address(proxy));

        StakingMining(address(proxy)).initialize(
            iceFrog,
            REWARD_PER_SECOND,
            block.timestamp + START_TIMESTAMP_DELTA,
            address(salesFactory)
        );
        vm.stopBroadcast();

        return (iceFrog, airdrop, salesFactory, address(proxy), helperConfig);
    }
}
