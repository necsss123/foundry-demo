// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {Deploy} from "../../../script/Deploy.s.sol";
import {HelperConfig} from "../../../script/HelperConfig.s.sol";
import {StakingMining} from "../../../src/StakingMining.sol";
import {IceFrog} from "../../../src/IceFrog.sol";
import {ContinueOnRevertHandler} from "./ContinueOnRevertHandler.t.sol";

contract ContinueOnRevertInvariantsTest is StdInvariant, Test {
    Deploy deployer;
    address stakingMiningProxy;
    HelperConfig helperConfig;
    StakingMining stakingMining;
    ContinueOnRevertHandler handler;
    IceFrog iceforg;

    function setUp() external {
        deployer = new Deploy();
        (iceforg, , , stakingMiningProxy, helperConfig) = deployer.run();
        stakingMining = StakingMining(stakingMiningProxy);
        handler = new ContinueOnRevertHandler(
            stakingMining,
            iceforg,
            helperConfig
        );
        targetContract(address(handler));
    }

    function invariant_PaidOutShouldNotExceedTotalRewards() public view {
        uint256 totalRewards = stakingMining.getTotalRewards();
        uint256 paidOut = stakingMining.getPaidOut();
        assert(paidOut <= totalRewards);
    }

    function invariant_TheAccERC20PerShareOfEachPoolShouldNotBeNegative()
        public
        view
    {
        uint256 accERC20PerSharePool0 = stakingMining
            .getPoolInfo(0)
            .accERC20PerShare;
        uint256 accERC20PerSharePool1 = stakingMining
            .getPoolInfo(1)
            .accERC20PerShare;
        assert(accERC20PerSharePool0 >= 0);
        assert(accERC20PerSharePool1 >= 0);
    }

    function invariant_gettersShouldNotRevert() public view {
        stakingMining.getEndTimestamp();
        stakingMining.getPaidOut();
        stakingMining.getPoolNum();
        stakingMining.getRewardPerSec();
        stakingMining.getRewardToken();
        stakingMining.getStakingMiningDuration();
        stakingMining.getStartTimestamp();
        stakingMining.getTotalAllocPoint();
        stakingMining.getTotalPending();
        stakingMining.getTotalRewards();
        stakingMining.getPoolInfo(0);
        stakingMining.getPoolInfo(1);
    }
}
