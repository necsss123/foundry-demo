/*
* Verification of GasBadStakingMining
*/

using GasBadStakingMining as gasBadStakingMining;
using StakingMining as stakingMining;

methods {
    function getTotalPending() external returns uint256 envfree;

}

rule calling_any_function_should_result_in_each_contract_having_the_same_state(method f, method f2) {
    require(f.selector == f2.selector);

    env e;
    calldataarg args;

    require(gasBadStakingMining.getTotalPending(e) == stakingMining.getTotalPending());

    gasBadStakingMining.f(e, args);
    stakingMining.f(e, args);

    assert(gasBadStakingMining.getTotalPending(e) == stakingMining.getTotalPending());
    // "test/mocks/NftMock.sol:NftMock"
}