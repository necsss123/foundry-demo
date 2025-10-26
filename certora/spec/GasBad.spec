/*
* Verification of GasBadStakingMining
*/

using GasBadStakingMining as gasBadStakingMining;
using StakingMining as stakingMining;
using IceFrog as rewardToken;
// using DummyErc20 as dummyToken0;
// using Dummy1Erc20 as dummyToken1;


methods {
    function getTotalPending() external returns uint256;  // 跟env中的block.timestamp有关，舍弃envfree
    function getStartTimestamp() external returns uint256 envfree;
    function getEndTimestamp() external returns uint256 envfree;
    function getPaidOut() external returns uint256 envfree;
    function StakingMining.getPoolInfo(uint256) external returns StakingMining.Pool envfree;
    function GasBadStakingMining.getPoolInfo(uint256) external returns GasBadStakingMining.Pool envfree;
    function StakingMining.getUserInfoInPool(uint256, address) external returns StakingMining.User envfree;
    function GasBadStakingMining.getUserInfoInPool(uint256, address) external returns GasBadStakingMining.User envfree;
    function getRewardPerSec() external returns uint256 envfree;

    function _.proxiableUUID() external => DISPATCHER(true);
    function _.transfer(address,uint256) external => DISPATCHER(true);
    function _.transferFrom(address,address,uint256) external => DISPATCHER(true);
    
}


rule calling_any_function_should_result_in_each_contract_having_the_same_state(method f, method f2) {
    
    require(f.selector == f2.selector);

    env e;
    calldataarg args;
    uint256 poolId;
    address user;

    require(gasBadStakingMining.getTotalPending(e) == stakingMining.getTotalPending(e));
    require(gasBadStakingMining.getStartTimestamp(e) == stakingMining.getStartTimestamp(e));
    require(gasBadStakingMining.getEndTimestamp(e) == stakingMining.getEndTimestamp(e));
    require(gasBadStakingMining.getPaidOut(e) == stakingMining.getPaidOut(e));
    require(gasBadStakingMining.getRewardPerSec(e) == stakingMining.getRewardPerSec(e));
    require(gasBadStakingMining.getPoolInfo(e,poolId).accERC20PerShare == stakingMining.getPoolInfo(e,poolId).accERC20PerShare);
    require(gasBadStakingMining.getUserInfoInPool(e, poolId, user).amount ==  stakingMining.getUserInfoInPool(e, poolId, user).amount );
    require(gasBadStakingMining.getUserInfoInPool(e, poolId, user).rewardDebt ==  stakingMining.getUserInfoInPool(e, poolId, user).rewardDebt );


    gasBadStakingMining.f(e, args);
    stakingMining.f2(e, args);

    assert(gasBadStakingMining.getTotalPending(e) == stakingMining.getTotalPending(e));

}