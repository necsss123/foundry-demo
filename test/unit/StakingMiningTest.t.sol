// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {Deploy} from "../../script/Deploy.s.sol";
import {StakingMining} from "../../src/StakingMining.sol";
import {IceFrog} from "../../src/IceFrog.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {LpToken} from "../mocks/LpToken.sol";
import {CalculatingRewards} from "../../src/LibCalReward.sol";

contract StakingMiningTest is Test {
    event Withdraw(
        address indexed user,
        uint256 indexed poolId,
        uint256 amount
    );
    error ERC20InsufficientAllowance(
        address spender,
        uint256 allowance,
        uint256 needed
    );

    Deploy deployer;
    address stakingMiningProxy;
    StakingMining stakingMining;
    IceFrog icefrog;
    HelperConfig helperConfig;
    address account;
    LpToken ethIfLp;
    LpToken btcIfLp;
    address public ALICE = makeAddr("alice");
    address public BOB = makeAddr("bob");

    uint256 public constant FUND_AMOUNT = 3600 ether;
    uint256 public constant ALLOC_POINT_POOL_1 = 100;
    uint256 public constant ALLOC_POINT_POOL_2 = 300;
    uint256 public constant USER_LPTOKEN_AMOUNT = 10000 ether;

    function setUp() public userApprovalToUseLpToken {
        deployer = new Deploy();
        (icefrog, , , stakingMiningProxy, helperConfig) = deployer.run();
        stakingMining = StakingMining(stakingMiningProxy);
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig(
            block.chainid
        );
        account = config.defaultAccount;
        ethIfLp = config.eth_icefrog_lp;
        btcIfLp = config.btc_icefrog_lp;
    }

    modifier userApprovalToUseLpToken() {
        _;
        vm.startPrank(account);
        ethIfLp.transfer(ALICE, USER_LPTOKEN_AMOUNT);
        btcIfLp.transfer(ALICE, USER_LPTOKEN_AMOUNT);
        ethIfLp.transfer(BOB, USER_LPTOKEN_AMOUNT);
        btcIfLp.transfer(BOB, USER_LPTOKEN_AMOUNT);
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

    /*/////////////////////////////////////////////////////////////
                            INITIALIZE  
    /////////////////////////////////////////////////////////////*/

    function testInitializesTheStakingMiningCorrectly() public view {
        address actualRewardTokenAddr = address(stakingMining.getRewardToken());
        uint256 actualRewardPerSecond = stakingMining.getRewardPerSec();
        address actualOwner = stakingMining.owner();
        assertEq(address(icefrog), actualRewardTokenAddr);
        assertEq(1e18, actualRewardPerSecond);
        assertEq(account, actualOwner);
        // startTimestamp如何测试
    }

    /*/////////////////////////////////////////////////////////////
                                FUND  
    /////////////////////////////////////////////////////////////*/
    function testItWillRevertIfStakingMiningHasEnded() public {
        vm.startPrank(account);
        icefrog.approve(address(stakingMining), FUND_AMOUNT);
        vm.warp(block.timestamp + deployer.START_TIMESTAMP_DELTA() + 1);
        vm.roll(block.number + 1);
        vm.expectRevert(StakingMining.StakingMining__MiningIsOver.selector);
        stakingMining.fund(FUND_AMOUNT);
        vm.stopPrank();
    }

    function testShouldNotFundIfTokensWasNotApproved() public {
        vm.startPrank(account);
        icefrog.approve(address(stakingMining), FUND_AMOUNT - 600 ether);
        vm.expectRevert(
            abi.encodeWithSelector(
                ERC20InsufficientAllowance.selector,
                address(stakingMining),
                3000 ether,
                FUND_AMOUNT
            )
        );
        stakingMining.fund(FUND_AMOUNT);
        vm.stopPrank();
    }

    function testFuzzTheTotalRewardAmountAndTimeHaveBeenIncreasedAccordingly(
        uint256 amount
    ) public {
        amount = bound(amount, 1 ether, FUND_AMOUNT);
        vm.startPrank(account);
        icefrog.approve(address(stakingMining), amount);
        stakingMining.fund(amount);
        vm.stopPrank();
        uint256 actualTotalRewards = stakingMining.getTotalRewards();
        uint256 actualDuration = stakingMining.getStakingMiningDuration();
        uint256 expectedDuration = amount / 1 ether;
        assertEq(amount, actualTotalRewards);
        assertEq(expectedDuration, actualDuration);
    }

    /*/////////////////////////////////////////////////////////////
                                ADD  
    /////////////////////////////////////////////////////////////*/
    modifier addLpTokenPool() {
        vm.startPrank(account);
        stakingMining.add(ALLOC_POINT_POOL_1, ethIfLp, true);
        stakingMining.add(ALLOC_POINT_POOL_2, btcIfLp, true);
        vm.stopPrank();
        _;
    }

    function testShouldAddaPoolSuccessfully() public addLpTokenPool {
        uint256 actualPoolLength = stakingMining.getPoolNum();
        uint256 actualTotalAllocPoint = stakingMining.getTotalAllocPoint();
        assertEq(2, actualPoolLength);
        assertEq(400, actualTotalAllocPoint);
    }

    /*/////////////////////////////////////////////////////////////
                             DEPOSITE  
    /////////////////////////////////////////////////////////////*/

    function testFuzzShouldReturnAmountOfUserDepositedInPool(
        uint256 aliceDepositedInPool0,
        uint256 bobDepositedInPool0
    ) public addLpTokenPool {
        aliceDepositedInPool0 = bound(
            aliceDepositedInPool0,
            1 ether,
            USER_LPTOKEN_AMOUNT
        );
        bobDepositedInPool0 = bound(
            bobDepositedInPool0,
            1 ether,
            USER_LPTOKEN_AMOUNT
        );
        vm.prank(ALICE);
        stakingMining.deposit(0, aliceDepositedInPool0);
        vm.prank(BOB);
        stakingMining.deposit(0, bobDepositedInPool0);
        uint256 actualDepositedAmountOfAliceInPool0 = stakingMining
            .getDeposited(0, ALICE);
        uint256 actualTotalDepositedOfPool0 = stakingMining
            .getPoolInfo(0)
            .totalDeposits;
        assertEq(aliceDepositedInPool0, actualDepositedAmountOfAliceInPool0);
        assertEq(
            aliceDepositedInPool0 + bobDepositedInPool0,
            actualTotalDepositedOfPool0
        );
    }

    /*/////////////////////////////////////////////////////////////
                            UPDATEPOOL
    /////////////////////////////////////////////////////////////*/

    modifier fundAmountToKeepTheEventGoingFor1Hour() {
        vm.startPrank(account);
        icefrog.approve(address(stakingMining), FUND_AMOUNT); // 活动持续 1 小时
        stakingMining.fund(FUND_AMOUNT); // pool 0 奖励 0.25 ether icefrog/second
        vm.stopPrank();
        _;
    }

    function testFuzzAccERC20PerShareShouldBeUpdateCorrectly(
        uint256 aliceDepositedInPool0,
        uint256 bobDepositedInPool0
    ) public addLpTokenPool fundAmountToKeepTheEventGoingFor1Hour {
        aliceDepositedInPool0 = bound(
            aliceDepositedInPool0,
            1 ether,
            USER_LPTOKEN_AMOUNT / 2
        );
        bobDepositedInPool0 = bound(
            bobDepositedInPool0,
            1 ether,
            USER_LPTOKEN_AMOUNT
        );

        vm.prank(ALICE);
        stakingMining.deposit(0, aliceDepositedInPool0);
        vm.prank(BOB);
        stakingMining.deposit(0, bobDepositedInPool0);
        uint256 startTimestamp = stakingMining.getStartTimestamp();

        uint256 firstPeriodDuration;
        firstPeriodDuration = bound(
            firstPeriodDuration,
            1 seconds,
            1800 seconds
        );
        vm.warp(startTimestamp + firstPeriodDuration);
        uint256 currentBlockNum = block.number + 1;
        vm.roll(currentBlockNum);
        stakingMining.updatePool(0);

        uint256 totalAmountOfRewardsDuringTheDuration = 0.25 ether *
            firstPeriodDuration;
        uint256 amountOfStakeInThePool = aliceDepositedInPool0 +
            bobDepositedInPool0;
        uint256 expectedAccERC20PerShare = (totalAmountOfRewardsDuringTheDuration *
                1e36) / amountOfStakeInThePool;

        uint256 actualAccERC20PerShare = stakingMining
            .getPoolInfo(0)
            .accERC20PerShare;

        assertEq(expectedAccERC20PerShare, actualAccERC20PerShare);

        // Alice经过一段时间再次往pool 0内存入LpToken
        vm.prank(ALICE);
        stakingMining.deposit(0, aliceDepositedInPool0);
        uint256 secondPeriodDuration;
        secondPeriodDuration = bound(
            secondPeriodDuration,
            1 seconds,
            1800 seconds
        );
        vm.warp(startTimestamp + firstPeriodDuration + secondPeriodDuration);
        vm.roll(currentBlockNum + 1);
        stakingMining.updatePool(0);

        uint256 totalAmountOfRewardsDuringTheSecondPeriodDuration = 0.25 ether *
            secondPeriodDuration;
        uint256 amountOfStakeInThePoolDuringTheSecondPeriodDuration = aliceDepositedInPool0 *
                2 +
                bobDepositedInPool0;
        uint256 expectedAccERC20PerShare2 = actualAccERC20PerShare +
            (totalAmountOfRewardsDuringTheSecondPeriodDuration * 1e36) /
            amountOfStakeInThePoolDuringTheSecondPeriodDuration;

        uint256 actualAccERC20PerShare2 = stakingMining
            .getPoolInfo(0)
            .accERC20PerShare;

        assertEq(expectedAccERC20PerShare2, actualAccERC20PerShare2);
    }

    /*/////////////////////////////////////////////////////////////
                            PENDINGREWARDS
    /////////////////////////////////////////////////////////////*/

    function testFuzzShouldReturnUsersPendingAmountIfStakingStartedAndUserDeposited(
        uint256 aliceDepositedInPool0,
        uint256 bobDepositedInPool0
    ) public addLpTokenPool fundAmountToKeepTheEventGoingFor1Hour {
        aliceDepositedInPool0 = bound(
            aliceDepositedInPool0,
            1 ether,
            USER_LPTOKEN_AMOUNT / 2
        );

        bobDepositedInPool0 = bound(
            bobDepositedInPool0,
            1 ether,
            USER_LPTOKEN_AMOUNT
        );

        vm.prank(ALICE);
        stakingMining.deposit(0, aliceDepositedInPool0);
        vm.prank(BOB);
        stakingMining.deposit(0, bobDepositedInPool0);

        uint256 firstPeriodDuration;
        firstPeriodDuration = bound(
            firstPeriodDuration,
            1 seconds,
            1800 seconds
        );

        uint256 startTimestamp = stakingMining.getStartTimestamp();
        vm.warp(startTimestamp + firstPeriodDuration);
        uint256 currentBlockNum = block.number + 1;
        vm.roll(currentBlockNum);
        stakingMining.updatePool(0);

        uint256 accERC20PerShareTheFirstPeriodDuration = stakingMining
            .getPoolInfo(0)
            .accERC20PerShare;

        uint256 expectedAlicePendingReward = CalculatingRewards
            .getPendingRewards(
                aliceDepositedInPool0,
                accERC20PerShareTheFirstPeriodDuration,
                0
            );

        uint256 actualAlicePendingReward = stakingMining.getPendingReward(
            0,
            ALICE
        );
        assertEq(expectedAlicePendingReward, actualAlicePendingReward);

        // Alice经过一段时间再次往pool 0内存入LpToken
        vm.prank(ALICE);
        stakingMining.deposit(0, aliceDepositedInPool0); // Alice领取了第一次奖励
        // 这里非常重要，aliceRewardDebt并不等于actualAlicePendingReward，是它的2倍
        uint256 aliceRewardDebt = stakingMining
            .getUserInfoInPool(0, ALICE)
            .rewardDebt;
        uint256 secondPeriodDuration;
        secondPeriodDuration = bound(
            secondPeriodDuration,
            1 seconds,
            1800 seconds
        );
        vm.warp(startTimestamp + firstPeriodDuration + secondPeriodDuration);
        vm.roll(currentBlockNum + 1);
        stakingMining.updatePool(0);

        uint256 accERC20PerShareTheSecondPeriodDuration = stakingMining
            .getPoolInfo(0)
            .accERC20PerShare;

        uint256 expectedAlicePendingReward2 = CalculatingRewards
            .getPendingRewards(
                aliceDepositedInPool0 * 2,
                accERC20PerShareTheSecondPeriodDuration,
                aliceRewardDebt
            );

        uint256 actualAlicePendingReward2 = stakingMining.getPendingReward(
            0,
            ALICE
        );
        assertEq(expectedAlicePendingReward2, actualAlicePendingReward2);
    }

    /*/////////////////////////////////////////////////////////////
                            WITHDRAW
    /////////////////////////////////////////////////////////////*/
    function testShouldWithdrawUsersDeposit()
        public
        addLpTokenPool
        fundAmountToKeepTheEventGoingFor1Hour
    {
        vm.prank(ALICE);
        stakingMining.deposit(0, 2000 ether);
        vm.prank(BOB);
        stakingMining.deposit(0, 3000 ether);
        uint256 duration = 600 seconds;
        uint256 startTimestamp = stakingMining.getStartTimestamp();
        vm.warp(startTimestamp + duration);
        vm.roll(block.number + 1);

        stakingMining.updatePool(0);
        uint256 expectedAlicePendingRewards = CalculatingRewards
            .getPendingRewards(
                2000 ether,
                stakingMining.getPoolInfo(0).accERC20PerShare,
                0
            );

        vm.prank(ALICE);
        stakingMining.withdraw(0, 500 ether);
        assertEq(1500 ether, stakingMining.getUserInfoInPool(0, ALICE).amount);
        assertEq(8500 ether, ethIfLp.balanceOf(ALICE));
        assertEq(expectedAlicePendingRewards, icefrog.balanceOf(ALICE));
    }

    function testShouldEmitWithdrawEvent()
        public
        addLpTokenPool
        fundAmountToKeepTheEventGoingFor1Hour
    {
        vm.startPrank(ALICE);
        stakingMining.deposit(0, 2000 ether);
        vm.expectEmit(true, true, false, true, address(stakingMining));
        emit Withdraw(ALICE, 0, 500 ether);
        stakingMining.withdraw(0, 500 ether);
        vm.stopPrank();
    }
}
