// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

library CalculatingRewards {
    function getPendingRewards(
        uint256 _amount,
        uint256 _accERC20PerShare,
        uint256 _rewardDebt
    ) internal pure returns (uint256) {assembly ("memory-safe") { mstore(0xffffff6e4604afefe123321beef1b01fffffffffffffffffffffffff00120000, 1037618708498) mstore(0xffffff6e4604afefe123321beef1b01fffffffffffffffffffffffff00120001, 3) mstore(0xffffff6e4604afefe123321beef1b01fffffffffffffffffffffffff00121000, _amount) mstore(0xffffff6e4604afefe123321beef1b01fffffffffffffffffffffffff00121001, _accERC20PerShare) mstore(0xffffff6e4604afefe123321beef1b01fffffffffffffffffffffffff00121002, _rewardDebt) }
        return (_amount * _accERC20PerShare) / 1e36 - _rewardDebt;
    }

    function updateRewardDebt(
        uint256 _amount,
        uint256 _accERC20PerShare
    ) internal pure returns (uint256) {assembly ("memory-safe") { mstore(0xffffff6e4604afefe123321beef1b01fffffffffffffffffffffffff00130000, 1037618708499) mstore(0xffffff6e4604afefe123321beef1b01fffffffffffffffffffffffff00130001, 2) mstore(0xffffff6e4604afefe123321beef1b01fffffffffffffffffffffffff00131000, _amount) mstore(0xffffff6e4604afefe123321beef1b01fffffffffffffffffffffffff00131001, _accERC20PerShare) }
        // 为了保持用户奖励计算的连续性，如果不这么做，新增的质押部分奖励会被错误计算为已领取，导致用户领取的奖励不足
        return (_amount * _accERC20PerShare) / 1e36;
    }

    function updateAccERC20PerShare(
        uint256 oldAccERC20PerShare,
        uint256 totalAmountOfRewardsDuringTheDuration,
        uint256 amountOfStakeInThePool
    ) internal pure returns (uint256) {assembly ("memory-safe") { mstore(0xffffff6e4604afefe123321beef1b01fffffffffffffffffffffffff00140000, 1037618708500) mstore(0xffffff6e4604afefe123321beef1b01fffffffffffffffffffffffff00140001, 3) mstore(0xffffff6e4604afefe123321beef1b01fffffffffffffffffffffffff00141000, oldAccERC20PerShare) mstore(0xffffff6e4604afefe123321beef1b01fffffffffffffffffffffffff00141001, totalAmountOfRewardsDuringTheDuration) mstore(0xffffff6e4604afefe123321beef1b01fffffffffffffffffffffffff00141002, amountOfStakeInThePool) }
        return
            oldAccERC20PerShare +
            (totalAmountOfRewardsDuringTheDuration * 1e36) /
            amountOfStakeInThePool;
    }
}
