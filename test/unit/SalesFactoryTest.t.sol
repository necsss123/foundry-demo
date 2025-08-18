// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {Deploy} from "../../script/Deploy.s.sol";
import {SalesFactory} from "../../src/sale/SalesFactory.sol";
import {IceFrogSale} from "../../src/sale/IceFrogSale.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {IceFrog} from "../../src/IceFrog.sol";
import {Vm} from "forge-std/Vm.sol";

contract SalesFactoryTest is Test {
    event SaleDeployed(address indexed saleContract);

    Deploy deployer;
    SalesFactory salesFactory;
    HelperConfig helperConfig;
    address account;
    address stakingMiningProxy;
    IceFrog icefrog;

    function setUp() public {
        deployer = new Deploy();
        (icefrog, , salesFactory, stakingMiningProxy, helperConfig) = deployer
            .run();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig(
            block.chainid
        );
        account = config.defaultAccount;
    }

    /*/////////////////////////////////////////////////////////////
                            CONSTRUCTOR  
    /////////////////////////////////////////////////////////////*/
    function testTheContractOwnerShouldBeTheDeployer() public view {
        address expectedOwner = salesFactory.owner();
        assertEq(expectedOwner, account);
    }

    function testShouldSetStakingMiningContractCorrectly() public view {
        address actualStakingMiningAddr = salesFactory.getStakingMiningAddr();
        assertEq(stakingMiningProxy, actualStakingMiningAddr);
    }

    /*/////////////////////////////////////////////////////////////
                            DEPLOYSALE  
    /////////////////////////////////////////////////////////////*/
    function testShouldDeploySaleSuccessfully() public {
        vm.prank(account);
        salesFactory.deploySale();
        uint256 actualSaleNum = salesFactory.getNumberOfSalesDeployed();
        address saleAddress = salesFactory.getLastDeployedSale();
        assertEq(1, actualSaleNum);
        assertEq(true, salesFactory.isSaleCreatedThroughFactory(saleAddress));
    }

    function testShouldEmitSaleDeployedEvent() public {
        vm.prank(account);
        vm.recordLogs();
        salesFactory.deploySale();
        Vm.Log[] memory entries = vm.getRecordedLogs();
        assertEq(entries[0].topics[0], keccak256("SaleDeployed(address)"));
        assertEq(
            entries[0].topics[1],
            bytes32(uint256(uint160(salesFactory.getLastDeployedSale())))
        );
    }

    /*/////////////////////////////////////////////////////////////
                            SETSALEPARAMS  
    /////////////////////////////////////////////////////////////*/
    function testShouldSetSaleParamsSuccessfully() public {
        vm.prank(account);
        salesFactory.deploySale();

        address saleAddress = salesFactory.getLastDeployedSale();
        vm.prank(account);
        IceFrogSale(payable(saleAddress)).setSaleParams(
            address(icefrog),
            account,
            10,
            10,
            block.timestamp + 100 seconds,
            block.timestamp + 10 seconds,
            100,
            1000000
        );

        IceFrogSale.Sale memory sale = IceFrogSale(payable(saleAddress))
            .getSale();
        assertEq(account, sale.saleOwner);
        assertEq(address(icefrog), address(sale.token));
    }
}
