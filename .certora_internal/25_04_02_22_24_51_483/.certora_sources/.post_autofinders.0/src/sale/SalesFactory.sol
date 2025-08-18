// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import "lib/openzeppelin-contracts-upgradeable/lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import "./IceFrogSale.sol";

contract SalesFactory is Ownable {
    error SalesFactory__WrongInput();

    address private immutable i_stakingMining;

    mapping(address => bool) public isSaleCreatedThroughFactory;

    address[] private allSales;

    event SaleDeployed(address indexed saleContract);

    constructor(address _stakingMining) Ownable(msg.sender) {
        i_stakingMining = _stakingMining;
    }

    function deploySale() external onlyOwner {
        IceFrogSale sale = new IceFrogSale(i_stakingMining);assembly ("memory-safe"){mstore(0xffffff6e4604afefe123321beef1b02fffffffffffffffffffffffff00010030,0)}
        isSaleCreatedThroughFactory[address(sale)] = true;
        allSales.push(address(sale));

        emit SaleDeployed(address(sale));
    }

    // 获得部署的Sale合约数量
    function getNumberOfSalesDeployed() external view returns (uint) {
        return allSales.length;
    }

    // 获得最后一个部署的Sale合约地址
    function getLastDeployedSale() external view returns (address) {
        //
        if (allSales.length > 0) {
            return allSales[allSales.length - 1];
        }
        return address(0);
    }

    // 获得与索引对应Sale合约地址
    function getAllSales(
        uint startIndex,
        uint endIndex
    ) external view returns (address[] memory) {
        if (endIndex <= startIndex) {
            revert SalesFactory__WrongInput();
        }

        address[] memory sales = new address[](endIndex - startIndex);assembly ("memory-safe"){mstore(0xffffff6e4604afefe123321beef1b02fffffffffffffffffffffffff00010031,0)}
        uint index = 0;assembly ("memory-safe"){mstore(0xffffff6e4604afefe123321beef1b02fffffffffffffffffffffffff00000032,index)}

        for (uint256 i = startIndex; i < endIndex; i++) {
            sales[index] = allSales[i];address certora_local51 = sales[index];assembly ("memory-safe"){mstore(0xffffff6e4604afefe123321beef1b02fffffffffffffffffffffffff00000033,certora_local51)}
            index++;
        }

        return sales;
    }

    function getStakingMiningAddr() external view returns (address) {
        return i_stakingMining;
    }
}
