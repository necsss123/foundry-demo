/*
* Verification of GasBadStakingMining
*/

using GasBadStakingMining as gasBadStakingMining;
using StakingMining as stakingMining;

methods {
    function getTotalPending() external returns uint256;  // 依赖 env的 block.timestamp

}

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