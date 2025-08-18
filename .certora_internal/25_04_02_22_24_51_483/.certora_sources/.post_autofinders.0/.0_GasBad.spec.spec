/*
* Verification of GasBadStakingMining
*/

using GasBadStakingMining as gasBadStakingMining;
using StakingMining as stakingMining;

methods {
    function getTotalPending() external returns uint256;  // 依赖 env的 block.timestamp
    function _.proxiableUUID() external => DISPATCHER(true);
    function _.transfer(address, uint256) external returns bool => DISPATCHER(true);
    
}


// invariant   奖励总额小于存入的奖励数额

rule calling_any_function_should_result_in_each_contract_having_the_same_state(method f, method f2) {
    require(f.selector == f2.selector);

    env e;
    calldataarg args;

    require(gasBadStakingMining.getTotalPending(e) == stakingMining.getTotalPending(e));

    gasBadStakingMining.f(e, args);
    stakingMining.f2(e, args);

    assert(gasBadStakingMining.getTotalPending(e) == stakingMining.getTotalPending(e));
    // "test/mocks/NftMock.sol:NftMock"
}