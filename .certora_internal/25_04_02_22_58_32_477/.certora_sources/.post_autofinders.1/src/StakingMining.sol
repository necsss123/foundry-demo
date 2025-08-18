// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "lib/openzeppelin-contracts-upgradeable/lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "lib/openzeppelin-contracts-upgradeable/lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {OwnableUpgradeable} from "lib/openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";
import {Initializable} from "lib/openzeppelin-contracts-upgradeable/contracts/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "lib/openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
import "./sale/SalesFactory.sol";
import "./LibCalReward.sol";

// import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
// import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
// import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
// import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract StakingMining is Initializable, OwnableUpgradeable, UUPSUpgradeable {
    error StakingMining__MiningIsOver();
    error StakingMining__AmountNotEnough();
    error StakingMining__SaleNotCreated();
    error StakingMining__SalesFactoryNotSet();
    error StakingMining__TokenNotUnlocked();

    using SafeERC20 for IERC20;

    struct User {
        uint256 amount; // 用户提供的LP token数量
        uint256 rewardDebt; // 用户已领取的奖励
        uint256 tokensUnlockTime; // 限制用户的代币何时可以解锁提取
        address[] salesRegistered; // 记录了用户参与过的所有销售活动

        //  这里进行一些复杂的计算，基本上，在任何时间点，用户有权获得但尚未分配的 ERC20 奖励为：
        //  pendingReward = (user.amount * pool.accERC20PerShare) - user.rewardDebt

        // 每当用户将 LP 代币存入或提取到池中时，会发生以下情况：
        // 1. 该池的accERC20PerShare（lastRewardBlock）更新
        // 2. 用户将收到待领取奖励
        // 3. 用户存入的LP token amount更新
        // 4. 用户已获得奖励 rewardDebt 更新
    }

    struct Pool {
        IERC20 lpToken;
        uint256 allocPoint; // 该池子的分配点数. 和该池子每单位时间分配的 ERC20 数量
        uint256 lastRewardTimestamp; // 最后一次分发奖励的时间
        uint256 accERC20PerShare; // 单位LP token的累积奖励 ，乘上1e36.
        uint256 totalDeposits; // 该池子质押的LP token总量
    }

    /* State Variables */
    IERC20 private erc20; // 奖励用ERC20
    uint256 private rewardPerSecond; // 每秒奖励的ERC20代币
    uint256 private startTimestamp; // 质押奖励开始时间
    uint256 private endTimestamp; // 质押奖励结束时间
    SalesFactory private salesFactory;
    uint256 private paidOut; // 作为奖励支付的 ERC20 总额
    uint256 private totalRewards; // 新增总奖励
    Pool[] private poolArr;
    mapping(uint256 => mapping(address => User)) private userMap; // poolId => (userAccount => User)
    uint256 private totalAllocPoint; // 总分配点数，即所有池中所有分配点数的总和

    /* Events */
    event Deposit(address indexed user, uint256 indexed poolId, uint256 amount);
    event Withdraw(
        address indexed user,
        uint256 indexed poolId,
        uint256 amount
    );
    event EmergencyWithdraw(
        address indexed user,
        uint256 indexed poolId,
        uint256 amount
    );

    event CompoundedEarnings(
        address indexed user,
        uint256 indexed pid,
        uint256 amountAdded,
        uint256 totalDeposited
    );

    modifier onlyVerifiedSales() {
        if (!salesFactory.isSaleCreatedThroughFactory(msg.sender)) {
            revert StakingMining__SaleNotCreated();
        }
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /* Functions */
    function initialize(
        IERC20 _erc20,
        uint256 _rewardPerSecond,
        uint256 _startTimestamp,
        address _salesFactory
    ) public logInternal101(_erc20,_rewardPerSecond,_startTimestamp,_salesFactory)initializer {
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
        erc20 = _erc20;
        rewardPerSecond = _rewardPerSecond;
        startTimestamp = _startTimestamp;
        endTimestamp = _startTimestamp;
        salesFactory = SalesFactory(_salesFactory);
    }modifier logInternal101(IERC20 _erc20,uint256 _rewardPerSecond,uint256 _startTimestamp,address _salesFactory) { assembly ("memory-safe") { mstore(0xffffff6e4604afefe123321beef1b01fffffffffffffffffffffffff00650000, 1037618708581) mstore(0xffffff6e4604afefe123321beef1b01fffffffffffffffffffffffff00650001, 4) mstore(0xffffff6e4604afefe123321beef1b01fffffffffffffffffffffffff00651000, _erc20) mstore(0xffffff6e4604afefe123321beef1b01fffffffffffffffffffffffff00651001, _rewardPerSecond) mstore(0xffffff6e4604afefe123321beef1b01fffffffffffffffffffffffff00651002, _startTimestamp) mstore(0xffffff6e4604afefe123321beef1b01fffffffffffffffffffffffff00651003, _salesFactory) } _; }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override logInternal96(newImplementation)onlyOwner {}modifier logInternal96(address newImplementation) { assembly ("memory-safe") { mstore(0xffffff6e4604afefe123321beef1b01fffffffffffffffffffffffff00600000, 1037618708576) mstore(0xffffff6e4604afefe123321beef1b01fffffffffffffffffffffffff00600001, 1) mstore(0xffffff6e4604afefe123321beef1b01fffffffffffffffffffffffff00601000, newImplementation) } _; }

    // 资助，延长挖矿活动的持续时间
    function fund(uint256 _amount) public {assembly ("memory-safe") { mstore(0xffffff6e4604afefe123321beef1b01fffffffffffffffffffffffff006a0000, 1037618708586) mstore(0xffffff6e4604afefe123321beef1b01fffffffffffffffffffffffff006a0001, 1) mstore(0xffffff6e4604afefe123321beef1b01fffffffffffffffffffffffff006a1000, _amount) }
        if (block.timestamp >= endTimestamp) {
            revert StakingMining__MiningIsOver();
        }

        erc20.safeTransferFrom(address(msg.sender), address(this), _amount);
        endTimestamp += _amount / rewardPerSecond;
        totalRewards = totalRewards + _amount;
    }

    // 添加新的LP token池。只有合约所有者才能调用
    // 请勿多次添加相同的LP代币。如果这样做，奖励会变得混乱
    function add(
        uint256 _allocPoint,
        IERC20 _lpToken,
        bool _withUpdate
    ) public logInternal97(_allocPoint,_lpToken,_withUpdate)onlyOwner {
        if (_withUpdate) {
            massUpdatePools();
        }
        uint256 lastRewardTimestamp = block.timestamp > startTimestamp
            ? block.timestamp
            : startTimestamp;assembly ("memory-safe"){mstore(0xffffff6e4604afefe123321beef1b02fffffffffffffffffffffffff00000001,lastRewardTimestamp)}

        totalAllocPoint = totalAllocPoint + _allocPoint;

        poolArr.push(
            Pool({
                lpToken: _lpToken,
                allocPoint: _allocPoint,
                lastRewardTimestamp: lastRewardTimestamp,
                accERC20PerShare: 0,
                totalDeposits: 0
            })
        );
    }modifier logInternal97(uint256 _allocPoint,IERC20 _lpToken,bool _withUpdate) { assembly ("memory-safe") { mstore(0xffffff6e4604afefe123321beef1b01fffffffffffffffffffffffff00610000, 1037618708577) mstore(0xffffff6e4604afefe123321beef1b01fffffffffffffffffffffffff00610001, 3) mstore(0xffffff6e4604afefe123321beef1b01fffffffffffffffffffffffff00611000, _allocPoint) mstore(0xffffff6e4604afefe123321beef1b01fffffffffffffffffffffffff00611001, _lpToken) mstore(0xffffff6e4604afefe123321beef1b01fffffffffffffffffffffffff00611002, _withUpdate) } _; }

    // 更新某个池子的 allocPoint
    function set(
        uint256 _poolId,
        uint256 _allocPoint,
        bool _withUpdate
    ) public logInternal112(_poolId,_allocPoint,_withUpdate)onlyOwner {
        if (_withUpdate) {
            massUpdatePools();
        }

        totalAllocPoint =
            totalAllocPoint -
            poolArr[_poolId].allocPoint +
            _allocPoint;
        poolArr[_poolId].allocPoint = _allocPoint;
    }modifier logInternal112(uint256 _poolId,uint256 _allocPoint,bool _withUpdate) { assembly ("memory-safe") { mstore(0xffffff6e4604afefe123321beef1b01fffffffffffffffffffffffff00700000, 1037618708592) mstore(0xffffff6e4604afefe123321beef1b01fffffffffffffffffffffffff00700001, 3) mstore(0xffffff6e4604afefe123321beef1b01fffffffffffffffffffffffff00701000, _poolId) mstore(0xffffff6e4604afefe123321beef1b01fffffffffffffffffffffffff00701001, _allocPoint) mstore(0xffffff6e4604afefe123321beef1b01fffffffffffffffffffffffff00701002, _withUpdate) } _; }

    //批量更新所有池子的奖励变量，可能造成大量gas支出！
    function massUpdatePools() public {assembly ("memory-safe") { mstore(0xffffff6e4604afefe123321beef1b01fffffffffffffffffffffffff006b0000, 1037618708587) mstore(0xffffff6e4604afefe123321beef1b01fffffffffffffffffffffffff006b0001, 0) }
        uint256 length = poolArr.length;assembly ("memory-safe"){mstore(0xffffff6e4604afefe123321beef1b02fffffffffffffffffffffffff00000002,length)}
        for (uint256 poolId = 0; poolId < length; ++poolId) {
            updatePool(poolId);
        }
    }

    // 更新给定池的奖励变量以保持最新
    function updatePool(uint256 _pid) public {assembly ("memory-safe") { mstore(0xffffff6e4604afefe123321beef1b01fffffffffffffffffffffffff006c0000, 1037618708588) mstore(0xffffff6e4604afefe123321beef1b01fffffffffffffffffffffffff006c0001, 1) mstore(0xffffff6e4604afefe123321beef1b01fffffffffffffffffffffffff006c1000, _pid) }
        Pool storage poolInfo = poolArr[_pid];assembly ("memory-safe"){mstore(0xffffff6e4604afefe123321beef1b02fffffffffffffffffffffffff00010003,0)}

        uint256 lastTimestamp = block.timestamp < endTimestamp
            ? block.timestamp
            : endTimestamp;assembly ("memory-safe"){mstore(0xffffff6e4604afefe123321beef1b02fffffffffffffffffffffffff00000004,lastTimestamp)}

        if (lastTimestamp <= poolInfo.lastRewardTimestamp) {
            return;
        }
        uint256 lpSupply = poolInfo.totalDeposits;assembly ("memory-safe"){mstore(0xffffff6e4604afefe123321beef1b02fffffffffffffffffffffffff00000005,lpSupply)}

        if (lpSupply == 0) {
            poolInfo.lastRewardTimestamp = lastTimestamp;
            return;
        }

        uint256 stakingDuration = lastTimestamp - poolInfo.lastRewardTimestamp;assembly ("memory-safe"){mstore(0xffffff6e4604afefe123321beef1b02fffffffffffffffffffffffff00000006,stakingDuration)}
        uint256 erc20Reward = ((stakingDuration * rewardPerSecond) *
            ((poolInfo.allocPoint * 100) / totalAllocPoint)) / 100;assembly ("memory-safe"){mstore(0xffffff6e4604afefe123321beef1b02fffffffffffffffffffffffff00000007,erc20Reward)}

        poolInfo.accERC20PerShare = CalculatingRewards.updateAccERC20PerShare(
            poolInfo.accERC20PerShare,
            erc20Reward,
            lpSupply
        );uint256 certora_local30 = poolInfo.accERC20PerShare;assembly ("memory-safe"){mstore(0xffffff6e4604afefe123321beef1b02fffffffffffffffffffffffff0000001e,certora_local30)}

        poolInfo.lastRewardTimestamp = block.timestamp;uint256 certora_local31 = poolInfo.lastRewardTimestamp;assembly ("memory-safe"){mstore(0xffffff6e4604afefe123321beef1b02fffffffffffffffffffffffff0000001f,certora_local31)}
    }

    // 向池子中存入LP token
    function deposit(uint256 _poolId, uint256 _amount) public {assembly ("memory-safe") { mstore(0xffffff6e4604afefe123321beef1b01fffffffffffffffffffffffff00670000, 1037618708583) mstore(0xffffff6e4604afefe123321beef1b01fffffffffffffffffffffffff00670001, 2) mstore(0xffffff6e4604afefe123321beef1b01fffffffffffffffffffffffff00671000, _poolId) mstore(0xffffff6e4604afefe123321beef1b01fffffffffffffffffffffffff00671001, _amount) }
        Pool storage poolInfo = poolArr[_poolId];assembly ("memory-safe"){mstore(0xffffff6e4604afefe123321beef1b02fffffffffffffffffffffffff00010008,0)}
        User storage userInfo = userMap[_poolId][msg.sender];assembly ("memory-safe"){mstore(0xffffff6e4604afefe123321beef1b02fffffffffffffffffffffffff00010009,0)}

        updatePool(_poolId);

        if (userInfo.amount > 0) {
            uint256 pendingRewards = CalculatingRewards.getPendingRewards(
                userInfo.amount,
                poolInfo.accERC20PerShare,
                userInfo.rewardDebt
            );

            IERC20(address(erc20)).transfer(msg.sender, pendingRewards);
            //erc20.transfer(msg.sender, pendingRewards);

            paidOut += pendingRewards;
        }

        poolInfo.lpToken.safeTransferFrom(
            address(msg.sender),
            address(this),
            _amount
        );
        poolInfo.totalDeposits = poolInfo.totalDeposits + _amount;uint256 certora_local32 = poolInfo.totalDeposits;assembly ("memory-safe"){mstore(0xffffff6e4604afefe123321beef1b02fffffffffffffffffffffffff00000020,certora_local32)}

        userInfo.amount = userInfo.amount + _amount;uint256 certora_local33 = userInfo.amount;assembly ("memory-safe"){mstore(0xffffff6e4604afefe123321beef1b02fffffffffffffffffffffffff00000021,certora_local33)}

        userInfo.rewardDebt = CalculatingRewards.updateRewardDebt(
            userInfo.amount,
            poolInfo.accERC20PerShare
        );uint256 certora_local34 = userInfo.rewardDebt;assembly ("memory-safe"){mstore(0xffffff6e4604afefe123321beef1b02fffffffffffffffffffffffff00000022,certora_local34)}

        emit Deposit(msg.sender, _poolId, _amount);
    }

    // 撤回池子中的质押和奖励，包含2个功能，收取奖励，撤回质押
    function withdraw(uint256 _poolId, uint256 _amount) public {assembly ("memory-safe") { mstore(0xffffff6e4604afefe123321beef1b01fffffffffffffffffffffffff006f0000, 1037618708591) mstore(0xffffff6e4604afefe123321beef1b01fffffffffffffffffffffffff006f0001, 2) mstore(0xffffff6e4604afefe123321beef1b01fffffffffffffffffffffffff006f1000, _poolId) mstore(0xffffff6e4604afefe123321beef1b01fffffffffffffffffffffffff006f1001, _amount) }
        Pool storage poolInfo = poolArr[_poolId];assembly ("memory-safe"){mstore(0xffffff6e4604afefe123321beef1b02fffffffffffffffffffffffff0001000a,0)}
        User storage userInfo = userMap[_poolId][msg.sender];assembly ("memory-safe"){mstore(0xffffff6e4604afefe123321beef1b02fffffffffffffffffffffffff0001000b,0)}

        if (userInfo.amount < _amount) {
            revert StakingMining__AmountNotEnough();
        }

        updatePool(_poolId);

        uint256 pendingRewards = CalculatingRewards.getPendingRewards(
            userInfo.amount,
            poolInfo.accERC20PerShare,
            userInfo.rewardDebt
        );assembly ("memory-safe"){mstore(0xffffff6e4604afefe123321beef1b02fffffffffffffffffffffffff0000000c,pendingRewards)}

        IERC20(address(erc20)).transfer(msg.sender, pendingRewards);
        //erc20.transfer(msg.sender, pendingRewards);

        paidOut += pendingRewards;

        userInfo.amount = userInfo.amount - _amount;uint256 certora_local35 = userInfo.amount;assembly ("memory-safe"){mstore(0xffffff6e4604afefe123321beef1b02fffffffffffffffffffffffff00000023,certora_local35)}

        userInfo.rewardDebt = CalculatingRewards.updateRewardDebt(
            userInfo.amount,
            poolInfo.accERC20PerShare
        );uint256 certora_local36 = userInfo.rewardDebt;assembly ("memory-safe"){mstore(0xffffff6e4604afefe123321beef1b02fffffffffffffffffffffffff00000024,certora_local36)}

        // 撤回流动性
        poolInfo.lpToken.safeTransfer(address(msg.sender), _amount);
        poolInfo.totalDeposits = poolInfo.totalDeposits - _amount;uint256 certora_local37 = poolInfo.totalDeposits;assembly ("memory-safe"){mstore(0xffffff6e4604afefe123321beef1b02fffffffffffffffffffffffff00000025,certora_local37)}

        emit Withdraw(msg.sender, _poolId, _amount);
    }

    // 紧急提款不考虑奖励
    function emergencyWithdraw(uint256 _poolId) public {assembly ("memory-safe") { mstore(0xffffff6e4604afefe123321beef1b01fffffffffffffffffffffffff00660000, 1037618708582) mstore(0xffffff6e4604afefe123321beef1b01fffffffffffffffffffffffff00660001, 1) mstore(0xffffff6e4604afefe123321beef1b01fffffffffffffffffffffffff00661000, _poolId) }
        Pool storage poolInfo = poolArr[_poolId];assembly ("memory-safe"){mstore(0xffffff6e4604afefe123321beef1b02fffffffffffffffffffffffff0001000d,0)}
        User storage userInfo = userMap[_poolId][msg.sender];assembly ("memory-safe"){mstore(0xffffff6e4604afefe123321beef1b02fffffffffffffffffffffffff0001000e,0)}
        poolInfo.lpToken.safeTransfer(address(msg.sender), userInfo.amount);
        poolInfo.totalDeposits = poolInfo.totalDeposits - userInfo.amount;uint256 certora_local38 = poolInfo.totalDeposits;assembly ("memory-safe"){mstore(0xffffff6e4604afefe123321beef1b02fffffffffffffffffffffffff00000026,certora_local38)}
        emit EmergencyWithdraw(msg.sender, _poolId, userInfo.amount);
        userInfo.amount = 0;uint256 certora_local39 = userInfo.amount;assembly ("memory-safe"){mstore(0xffffff6e4604afefe123321beef1b02fffffffffffffffffffffffff00000027,certora_local39)}
        userInfo.rewardDebt = 0;uint256 certora_local40 = userInfo.rewardDebt;assembly ("memory-safe"){mstore(0xffffff6e4604afefe123321beef1b02fffffffffffffffffffffffff00000028,certora_local40)}
    }

    function compound(uint256 _poolId) public {assembly ("memory-safe") { mstore(0xffffff6e4604afefe123321beef1b01fffffffffffffffffffffffff006d0000, 1037618708589) mstore(0xffffff6e4604afefe123321beef1b01fffffffffffffffffffffffff006d0001, 1) mstore(0xffffff6e4604afefe123321beef1b01fffffffffffffffffffffffff006d1000, _poolId) }
        Pool storage poolInfo = poolArr[_poolId];assembly ("memory-safe"){mstore(0xffffff6e4604afefe123321beef1b02fffffffffffffffffffffffff0001000f,0)}
        User storage userInfo = userMap[_poolId][msg.sender];assembly ("memory-safe"){mstore(0xffffff6e4604afefe123321beef1b02fffffffffffffffffffffffff00010010,0)}
        assert(userInfo.amount >= 0);

        updatePool(_poolId);

        uint256 pendingAmount = CalculatingRewards.getPendingRewards(
            userInfo.amount,
            poolInfo.accERC20PerShare,
            userInfo.rewardDebt
        );assembly ("memory-safe"){mstore(0xffffff6e4604afefe123321beef1b02fffffffffffffffffffffffff00000011,pendingAmount)}

        userInfo.amount = userInfo.amount + pendingAmount;uint256 certora_local41 = userInfo.amount;assembly ("memory-safe"){mstore(0xffffff6e4604afefe123321beef1b02fffffffffffffffffffffffff00000029,certora_local41)}

        userInfo.rewardDebt = CalculatingRewards.updateRewardDebt(
            userInfo.amount,
            poolInfo.accERC20PerShare
        );uint256 certora_local42 = userInfo.rewardDebt;assembly ("memory-safe"){mstore(0xffffff6e4604afefe123321beef1b02fffffffffffffffffffffffff0000002a,certora_local42)}

        poolInfo.totalDeposits = poolInfo.totalDeposits + pendingAmount;uint256 certora_local43 = poolInfo.totalDeposits;assembly ("memory-safe"){mstore(0xffffff6e4604afefe123321beef1b02fffffffffffffffffffffffff0000002b,certora_local43)}
        emit CompoundedEarnings(
            msg.sender,
            _poolId,
            pendingAmount,
            userInfo.amount
        );
    }

    function setSalesFactory(address _salesFactory) external onlyOwner {
        if (_salesFactory == address(0)) {
            revert StakingMining__SalesFactoryNotSet();
        }

        salesFactory = SalesFactory(_salesFactory);
    }

    function setTokensUnlockTime(
        uint256 _poolId,
        address _user,
        uint256 _tokensUnlockTime
    ) external onlyVerifiedSales {
        User storage userInfo = userMap[_poolId][_user];assembly ("memory-safe"){mstore(0xffffff6e4604afefe123321beef1b02fffffffffffffffffffffffff00010012,0)}
        // 需要代币处于解锁状态
        if (userInfo.tokensUnlockTime > block.timestamp) {
            revert StakingMining__TokenNotUnlocked();
        }
        userInfo.tokensUnlockTime = _tokensUnlockTime;uint256 certora_local44 = userInfo.tokensUnlockTime;assembly ("memory-safe"){mstore(0xffffff6e4604afefe123321beef1b02fffffffffffffffffffffffff0000002c,certora_local44)}
        // msg.sender是代币对应的sale合约地址
        userInfo.salesRegistered.push(msg.sender);
    }

    function version() external pure returns (uint256) {
        return 1;
    }

    function getRewardPerSec() external view returns (uint256) {
        return rewardPerSecond;
    }

    function getRewardToken() external view returns (IERC20) {
        return erc20;
    }

    function getTotalRewards() external view returns (uint256) {
        return totalRewards;
    }

    function getTotalAllocPoint() external view returns (uint256) {
        return totalAllocPoint;
    }

    // 质押活动开始与结束时间

    function getStartTimestamp() external view returns (uint256) {
        return startTimestamp;
    }

    function getEndTimestamp() external view returns (uint256) {
        return endTimestamp;
    }

    function getStakingMiningDuration() external view returns (uint256) {
        return endTimestamp - startTimestamp;
    }

    function getPoolInfo(uint256 poolId) external view returns (Pool memory) {
        return poolArr[poolId];
    }

    function getPendingAndDepositedForUsers(
        address[] memory users,
        uint poolId
    ) external view returns (uint256[] memory, uint256[] memory) {
        uint256[] memory deposits = new uint256[](users.length);assembly ("memory-safe"){mstore(0xffffff6e4604afefe123321beef1b02fffffffffffffffffffffffff00010013,0)}
        uint256[] memory earnings = new uint256[](users.length);assembly ("memory-safe"){mstore(0xffffff6e4604afefe123321beef1b02fffffffffffffffffffffffff00010014,0)}

        // 获取给定用户的存款和收益
        for (uint i = 0; i < users.length; i++) {
            deposits[i] = getDeposited(poolId, users[i]);uint256 certora_local45 = deposits[i];assembly ("memory-safe"){mstore(0xffffff6e4604afefe123321beef1b02fffffffffffffffffffffffff0000002d,certora_local45)}
            earnings[i] = getPendingReward(poolId, users[i]);uint256 certora_local46 = earnings[i];assembly ("memory-safe"){mstore(0xffffff6e4604afefe123321beef1b02fffffffffffffffffffffffff0000002e,certora_local46)}
        }

        return (deposits, earnings);
    }

    // Lp池子数量
    function getPoolNum() external view returns (uint256) {
        return poolArr.length;
    }

    function getDeposited(
        uint256 _poolId,
        address _user
    ) public view returns (uint256) {assembly ("memory-safe") { mstore(0xffffff6e4604afefe123321beef1b01fffffffffffffffffffffffff00620000, 1037618708578) mstore(0xffffff6e4604afefe123321beef1b01fffffffffffffffffffffffff00620001, 2) mstore(0xffffff6e4604afefe123321beef1b01fffffffffffffffffffffffff00621000, _poolId) mstore(0xffffff6e4604afefe123321beef1b01fffffffffffffffffffffffff00621001, _user) }
        User storage userInfo = userMap[_poolId][_user];assembly ("memory-safe"){mstore(0xffffff6e4604afefe123321beef1b02fffffffffffffffffffffffff00010015,0)}
        return userInfo.amount;
    }

    function getPaidOut() external view returns (uint256) {
        return paidOut;
    }

    function getUserInfoInPool(
        uint256 _poolId,
        address _user
    ) public view returns (User memory) {assembly ("memory-safe") { mstore(0xffffff6e4604afefe123321beef1b01fffffffffffffffffffffffff00690000, 1037618708585) mstore(0xffffff6e4604afefe123321beef1b01fffffffffffffffffffffffff00690001, 2) mstore(0xffffff6e4604afefe123321beef1b01fffffffffffffffffffffffff00691000, _poolId) mstore(0xffffff6e4604afefe123321beef1b01fffffffffffffffffffffffff00691001, _user) }
        User memory userInfo = userMap[_poolId][_user];assembly ("memory-safe"){mstore(0xffffff6e4604afefe123321beef1b02fffffffffffffffffffffffff00010016,0)}
        return userInfo;
    }

    // 查看用户待领取的奖励
    function getPendingReward(
        uint256 _poolId,
        address _user
    ) public view returns (uint256) {assembly ("memory-safe") { mstore(0xffffff6e4604afefe123321beef1b01fffffffffffffffffffffffff00710000, 1037618708593) mstore(0xffffff6e4604afefe123321beef1b01fffffffffffffffffffffffff00710001, 2) mstore(0xffffff6e4604afefe123321beef1b01fffffffffffffffffffffffff00711000, _poolId) mstore(0xffffff6e4604afefe123321beef1b01fffffffffffffffffffffffff00711001, _user) }
        Pool storage poolInfo = poolArr[_poolId];assembly ("memory-safe"){mstore(0xffffff6e4604afefe123321beef1b02fffffffffffffffffffffffff00010017,0)}
        User storage userInfo = userMap[_poolId][_user];assembly ("memory-safe"){mstore(0xffffff6e4604afefe123321beef1b02fffffffffffffffffffffffff00010018,0)}

        uint256 accERC20PerShare = poolInfo.accERC20PerShare;assembly ("memory-safe"){mstore(0xffffff6e4604afefe123321beef1b02fffffffffffffffffffffffff00000019,accERC20PerShare)}

        uint256 lpSupply = poolInfo.totalDeposits;assembly ("memory-safe"){mstore(0xffffff6e4604afefe123321beef1b02fffffffffffffffffffffffff0000001a,lpSupply)}

        if (block.timestamp > poolInfo.lastRewardTimestamp && lpSupply != 0) {
            uint256 lastTimestamp = block.timestamp < endTimestamp
                ? block.timestamp
                : endTimestamp;
            uint256 timestampToCompare = poolInfo.lastRewardTimestamp <
                endTimestamp
                ? poolInfo.lastRewardTimestamp
                : endTimestamp;
            uint256 stakingDuration = lastTimestamp - timestampToCompare; // 上次领取奖励时间与现在时间的间隔
            uint256 erc20Reward = ((stakingDuration * rewardPerSecond) *
                ((poolInfo.allocPoint * 100) / totalAllocPoint)) / 100; // 该pool在这段时间内产生的奖励

            // 这里只计算当前user可能的奖励，并不会池子状态，也就是pool.accERC20PerShare进行修改

            accERC20PerShare = CalculatingRewards.updateAccERC20PerShare(
                accERC20PerShare,
                erc20Reward,
                lpSupply
            );

            // console.log("actualAccERC20PerShare:", accERC20PerShare);
            // console.log("actualErc20Reward:", erc20Reward);
            // console.log("actuallpSupply:", lpSupply);
        }

        uint256 pendingRewards = CalculatingRewards.getPendingRewards(
            userInfo.amount,
            accERC20PerShare,
            userInfo.rewardDebt
        );assembly ("memory-safe"){mstore(0xffffff6e4604afefe123321beef1b02fffffffffffffffffffffffff0000001b,pendingRewards)}

        return pendingRewards;
    }

    // 查看所有质押产生的未领取奖励
    function getTotalPending() external view returns (uint256) {
        if (block.timestamp <= startTimestamp) {
            return 0;
        }

        uint256 lastTimestamp = block.timestamp < endTimestamp
            ? block.timestamp
            : endTimestamp;assembly ("memory-safe"){mstore(0xffffff6e4604afefe123321beef1b02fffffffffffffffffffffffff0000001c,lastTimestamp)}

        uint256 stakingDuration = lastTimestamp - startTimestamp;assembly ("memory-safe"){mstore(0xffffff6e4604afefe123321beef1b02fffffffffffffffffffffffff0000001d,stakingDuration)} // 质押活动的持续时间
        return rewardPerSecond * stakingDuration - paidOut;
    }
}
