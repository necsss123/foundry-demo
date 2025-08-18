// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {StakingMining} from "../../../src/StakingMining.sol";
import {IceFrog} from "../../../src/IceFrog.sol";
import {HelperConfig} from "../../../script/HelperConfig.s.sol";
import {LpToken} from "../../mocks/LpToken.sol";

contract StopOnRevertHandler is Test {
    StakingMining stakingMining;
    IceFrog icefrog;
    HelperConfig helperConfig;
    address account;
    LpToken ethIfLp;
    LpToken btcIfLp;
    address public ALICE = makeAddr("alice");
    address public BOB = makeAddr("bob");

    uint256 public constant USER_LPTOKEN_AMOUNT = 10000 ether;
    uint256 public constant BONUS_FUNDS_TO_KEEP_THE_EVENT_GOING_FOR_1HOUR =
        3600 ether;
    uint256 public constant ALLOC_POINT_POOL_1 = 100;
    uint256 public constant ALLOC_POINT_POOL_2 = 300;

    constructor(
        StakingMining _stakingMining,
        IceFrog _icefrog,
        HelperConfig _helpConfig
    ) {
        stakingMining = _stakingMining;
        icefrog = _icefrog;
        helperConfig = _helpConfig;
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig(
            block.chainid
        );
        account = config.defaultAccount;
        ethIfLp = config.eth_icefrog_lp;
        btcIfLp = config.btc_icefrog_lp;
        fundAndAddTwoPools();
        stakingMiningStart();
    }

    function fundAndAddTwoPools() private {
        vm.startPrank(account);
        icefrog.approve(
            address(stakingMining),
            BONUS_FUNDS_TO_KEEP_THE_EVENT_GOING_FOR_1HOUR
        );
        stakingMining.fund(BONUS_FUNDS_TO_KEEP_THE_EVENT_GOING_FOR_1HOUR);
        ethIfLp.transfer(ALICE, USER_LPTOKEN_AMOUNT);
        btcIfLp.transfer(ALICE, USER_LPTOKEN_AMOUNT);
        ethIfLp.transfer(BOB, USER_LPTOKEN_AMOUNT);
        btcIfLp.transfer(BOB, USER_LPTOKEN_AMOUNT);
        stakingMining.add(ALLOC_POINT_POOL_1, ethIfLp, true);
        stakingMining.add(ALLOC_POINT_POOL_2, btcIfLp, true);
        vm.stopPrank();
        vm.startPrank(ALICE);
        ethIfLp.approve(address(stakingMining), USER_LPTOKEN_AMOUNT);
        btcIfLp.approve(address(stakingMining), USER_LPTOKEN_AMOUNT);
        vm.stopPrank();
        vm.startPrank(BOB);
        ethIfLp.approve(address(stakingMining), USER_LPTOKEN_AMOUNT);
        btcIfLp.approve(address(stakingMining), USER_LPTOKEN_AMOUNT);
        vm.stopPrank();
    }

    function stakingMiningStart() private {
        uint256 startTimestamp = stakingMining.getStartTimestamp();
        vm.warp(startTimestamp + 1 seconds);
        vm.roll(block.number + 1);
    }

    function deposit(
        uint256 poolSeed,
        uint256 userSeed,
        uint256 lpTokenAmount
    ) public {
        lpTokenAmount = bound(lpTokenAmount, 1 ether, 78 ether); // 10000 ether / 128 = 78 ether
        (uint256 poolId, address user) = _getPoolIdAndUserFromSeed(
            poolSeed,
            userSeed
        );
        vm.startPrank(user);
        stakingMining.deposit(poolId, lpTokenAmount);
        vm.stopPrank();
    }

    function _getPoolIdAndUserFromSeed(
        uint256 _poolSeed,
        uint256 _userSeed
    ) private view returns (uint256 poolId, address user) {
        if (_poolSeed % 2 == 0 && _userSeed % 2 == 0) {
            // pool 0 ethIfLp ,Alice
            return (0, ALICE);
        } else if (_poolSeed % 2 == 1 && _userSeed % 2 == 0) {
            // pool 1 btcIfLp ,Alice
            return (1, ALICE);
        } else if (_poolSeed % 2 == 0 && _userSeed % 2 == 1) {
            // pool 0 ethIfLp ,Bob
            return (0, BOB);
        } else if (_poolSeed % 2 == 1 && _userSeed % 2 == 1) {
            // pool 1 btcIfLp ,Bob
            return (1, BOB);
        }
    }

    function withdraw(
        uint256 poolSeed,
        uint256 userSeed,
        uint256 lpTokenAmount
    ) public {
        (uint256 poolId, address user) = _getPoolIdAndUserFromSeed(
            poolSeed,
            userSeed
        );
        uint256 maxLpTokenInPool = stakingMining
            .getUserInfoInPool(poolId, user)
            .amount;
        lpTokenAmount = bound(lpTokenAmount, 0, maxLpTokenInPool);
        if (lpTokenAmount == 0) {
            return;
        }
        vm.prank(user);
        stakingMining.withdraw(poolId, lpTokenAmount);
    }

    function emergencyWithdraw(uint256 poolSeed, uint256 userSeed) public {
        (uint256 poolId, address user) = _getPoolIdAndUserFromSeed(
            poolSeed,
            userSeed
        );
        uint256 lpTokenAmountInPool = stakingMining
            .getUserInfoInPool(poolId, user)
            .amount;
        if (lpTokenAmountInPool == 0) {
            return;
        }
        vm.prank(user);
        stakingMining.emergencyWithdraw(poolId);
    }
}
