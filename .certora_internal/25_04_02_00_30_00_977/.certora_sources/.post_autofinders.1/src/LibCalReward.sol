// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

library CalculatingRewards {
    function getPendingRewards(
        uint256 _amount,
        uint256 _accERC20PerShare,
        uint256 _rewardDebt
    ) internal pure returns (uint256) {assembly ("memory-safe") { mstore(0xffffff6e4604afefe123321beef1b01fffffffffffffffffffffffff005d0000, 1037618708573) mstore(0xffffff6e4604afefe123321beef1b01fffffffffffffffffffffffff005d0001, 3) mstore(0xffffff6e4604afefe123321beef1b01fffffffffffffffffffffffff005d1000, _amount) mstore(0xffffff6e4604afefe123321beef1b01fffffffffffffffffffffffff005d1001, _accERC20PerShare) mstore(0xffffff6e4604afefe123321beef1b01fffffffffffffffffffffffff005d1002, _rewardDebt) }
        return (_amount * _accERC20PerShare) / 1e36 - _rewardDebt;
    }

    function updateRewardDebt(
        uint256 _amount,
        uint256 _accERC20PerShare
    ) internal pure returns (uint256) {assembly ("memory-safe") { mstore(0xffffff6e4604afefe123321beef1b01fffffffffffffffffffffffff005e0000, 1037618708574) mstore(0xffffff6e4604afefe123321beef1b01fffffffffffffffffffffffff005e0001, 2) mstore(0xffffff6e4604afefe123321beef1b01fffffffffffffffffffffffff005e1000, _amount) mstore(0xffffff6e4604afefe123321beef1b01fffffffffffffffffffffffff005e1001, _accERC20PerShare) }
        // 为了保持用户奖励计算的连续性，如果不这么做，新增的质押部分奖励会被错误计算为已领取，导致用户领取的奖励不足
        return (_amount * _accERC20PerShare) / 1e36;
    }

    function updateAccERC20PerShare(
        uint256 oldAccERC20PerShare,
        uint256 totalAmountOfRewardsDuringTheDuration,
        uint256 amountOfStakeInThePool
    ) internal pure returns (uint256) {assembly ("memory-safe") { mstore(0xffffff6e4604afefe123321beef1b01fffffffffffffffffffffffff005f0000, 1037618708575) mstore(0xffffff6e4604afefe123321beef1b01fffffffffffffffffffffffff005f0001, 3) mstore(0xffffff6e4604afefe123321beef1b01fffffffffffffffffffffffff005f1000, oldAccERC20PerShare) mstore(0xffffff6e4604afefe123321beef1b01fffffffffffffffffffffffff005f1001, totalAmountOfRewardsDuringTheDuration) mstore(0xffffff6e4604afefe123321beef1b01fffffffffffffffffffffffff005f1002, amountOfStakeInThePool) }
        return
            oldAccERC20PerShare +
            (totalAmountOfRewardsDuringTheDuration * 1e36) /
            amountOfStakeInThePool;
    }
}
