// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {Deploy} from "../../script/Deploy.s.sol";
import {IceFrogSale} from "../../src/sale/IceFrogSale.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {SalesFactory} from "../../src/sale/SalesFactory.sol";
import {LpToken} from "../mocks/LpToken.sol";

contract IceFrogSaleTest is Test {
    event SaleCreated(
        address indexed saleOwner,
        uint256 tokenPriceInETH,
        uint256 amountOfTokensToSell,
        uint256 saleEnd
    );

    event RegistrationTimeSet(
        uint256 registrationTimeStarts,
        uint256 registrationTimeEnds
    );

    Deploy deployer;
    SalesFactory salesFactory;
    HelperConfig helperConfig;
    IceFrogSale sale;
    address account;
    uint256 accountPK;
    LpToken project_token;
    address stakingMiningProxy;

    address public PROJECT_PARTY = makeAddr("project_party");
    address public INVESTOR = makeAddr("investor");

    uint256 public constant PP_DEPOSITED_TOKENS = 3000 ether;

    function setUp() public {
        deployer = new Deploy();
        (, , salesFactory, , helperConfig) = deployer.run();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig(
            block.chainid
        );
        account = config.defaultAccount;
        accountPK = config.deployerKey;
        project_token = config.eth_icefrog_lp;
        vm.startPrank(account);
        salesFactory.deploySale();
        project_token.transfer(PROJECT_PARTY, PP_DEPOSITED_TOKENS);
        vm.stopPrank();
    }

    /*/////////////////////////////////////////////////////////////
                            CONSTRUCTOR  
    /////////////////////////////////////////////////////////////*/

    function testTheContractOwnerIsTheSalesFactoryDeveloper() public view {
        address actualOwner = salesFactory.owner();
        assertEq(account, actualOwner);
    }

    function testShouldNotAllowNonDeployerToSetSaleParams() public {
        address saleAddr = salesFactory.getLastDeployedSale();
        sale = IceFrogSale(payable(saleAddr));
        vm.prank(PROJECT_PARTY);
        vm.expectRevert(IceFrogSale.IceFrogSale__OnlyCallByAdmin.selector);
        sale.setSaleParams(
            address(project_token), // token address
            PROJECT_PARTY, // sale owner
            0.1 ether, // token price in Eth
            PP_DEPOSITED_TOKENS, // amount of token
            block.timestamp + 100, // sale end
            block.timestamp + 150, // token unclock time
            100, // portion vesting precision
            10000000 ether // max participation
        );
    }

    modifier getTheLastestDeployedSaleAndSetParams() {
        address saleAddr = salesFactory.getLastDeployedSale();
        sale = IceFrogSale(payable(saleAddr));
        vm.prank(account);
        sale.setSaleParams(
            address(project_token), // token address
            PROJECT_PARTY, // sale owner
            0.1 ether, // token price in Eth
            PP_DEPOSITED_TOKENS, // amount of token
            block.timestamp + 100, // sale end
            block.timestamp + 150, // token unclock time
            100, // portion vesting precision
            10000000 ether // max participation
        );
        _;
    }

    function testInitializesTheIceFrogSaleCorrectly()
        public
        getTheLastestDeployedSaleAndSetParams
    {
        address expectedStakingMiningAddr = address(sale.getStakingMining());
        address actualStakingMiningAddr = salesFactory.getStakingMiningAddr();
        address expectedSalesFactoryAddr = address(sale.getSalesFactory());
        address expectedSaleTokenAddr = address(sale.getSale().token);
        bool expectedSaleIsCreated = sale.getSale().isCreated;
        address expectedSaleOwner = sale.getSale().saleOwner;
        assertEq(expectedStakingMiningAddr, actualStakingMiningAddr);
        assertEq(expectedSalesFactoryAddr, address(salesFactory));
        assertEq(expectedSaleTokenAddr, address(project_token));
        assertEq(expectedSaleIsCreated, true);
        assertEq(expectedSaleOwner, PROJECT_PARTY);
    }

    function testShoudlEmitSaleCreatedEventWhenParamsAreSet() public {
        address saleAddr = salesFactory.getLastDeployedSale();
        sale = IceFrogSale(payable(saleAddr));
        vm.prank(account);
        vm.expectEmit(true, false, false, true, saleAddr);
        emit SaleCreated(
            PROJECT_PARTY,
            0.1 ether,
            3000 ether,
            block.timestamp + 100
        );
        sale.setSaleParams(
            address(project_token), // token address
            PROJECT_PARTY, // sale owner
            0.1 ether, // token price in Eth
            PP_DEPOSITED_TOKENS, // amount of token
            block.timestamp + 100, // sale end
            block.timestamp + 150, // token unclock time
            100, // portion vesting precision
            10000000 ether // max participation
        );
    }

    /*/////////////////////////////////////////////////////////////
                    SET REGISTRATI ON TIME  
    /////////////////////////////////////////////////////////////*/

    function testShouldSetTheRegistrationTimeCorrectly()
        public
        getTheLastestDeployedSaleAndSetParams
    {
        uint256 registrationStartTime = block.timestamp + 10;
        uint256 registrationEndTime = block.timestamp + 40;
        vm.prank(account);
        sale.setRegistrationTime(registrationStartTime, registrationEndTime);
        uint256 expectedRegistrationStartTime = sale
            .getRegistration()
            .registrationTimeStarts;
        uint256 expectedRegistrationEndTime = sale
            .getRegistration()
            .registrationTimeEnds;
        assertEq(expectedRegistrationStartTime, block.timestamp + 10);
        assertEq(expectedRegistrationEndTime, block.timestamp + 40);
    }

    function testShouldEmitRegistrationTimeSetWhenSettingRegistrationTime()
        public
        getTheLastestDeployedSaleAndSetParams
    {
        address saleAddr = salesFactory.getLastDeployedSale();
        uint256 registrationStartTime = block.timestamp + 10;
        uint256 registrationEndTime = block.timestamp + 40;
        vm.prank(account);
        vm.expectEmit(false, false, false, true, saleAddr);
        emit RegistrationTimeSet(registrationStartTime, registrationEndTime);
        sale.setRegistrationTime(registrationStartTime, registrationEndTime);
    }

    /*/////////////////////////////////////////////////////////////
                        DEPOSIT TOKENS  
    /////////////////////////////////////////////////////////////*/
    function testShouldAllowSaleOwnerToDepositTokens()
        public
        getTheLastestDeployedSaleAndSetParams
    {
        vm.startPrank(PROJECT_PARTY);
        project_token.approve(address(sale), PP_DEPOSITED_TOKENS);
        sale.depositTokens();
        vm.stopPrank();
        uint256 expectedAmountOfTokensToSell = project_token.balanceOf(
            address(sale)
        );
        assertEq(expectedAmountOfTokensToSell, PP_DEPOSITED_TOKENS);
    }

    function testShouldNotAllowNonSaleOwnerToDepositTokens()
        public
        getTheLastestDeployedSaleAndSetParams
    {
        vm.prank(account);
        vm.expectRevert(IceFrogSale.IceFrogSale__OnlyCallBySaleOwner.selector);
        sale.depositTokens();
    }

    /*/////////////////////////////////////////////////////////////
                        REGISTER FOR SALE  
    /////////////////////////////////////////////////////////////*/
    modifier setRegistrationTimeAndTheSaleStartTime() {
        uint256 registrationStartTime = block.timestamp + 10;
        uint256 registrationEndTime = block.timestamp + 40;
        uint256 saleStartTime = block.timestamp + 50;
        vm.startPrank(account);
        sale.setRegistrationTime(registrationStartTime, registrationEndTime);
        sale.setSaleStart(saleStartTime);
        vm.stopPrank();
        _;
    }

    function testShouldRegisterForSaleSuccessfully()
        public
        getTheLastestDeployedSaleAndSetParams
        setRegistrationTimeAndTheSaleStartTime
    {
        bytes32 msgHash = keccak256(abi.encodePacked(INVESTOR, address(sale)));
        bytes32 ethSignedMsgHash = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", msgHash)
        );
        // bytes32 ethSignedMsgHash = msgHash.toEthSignedMessageHash();
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(accountPK, ethSignedMsgHash);
        bytes memory sig = abi.encodePacked(r, s, v);
        vm.warp(block.timestamp + 10);
        vm.roll(block.number + 1);
        vm.prank(INVESTOR);
        sale.registerForSale(sig, 0);
        uint256 expectedTheNumOfRegisteredUsers = sale
            .getNumberOfRegisteredUsers();
        assertEq(expectedTheNumOfRegisteredUsers, 1);
    }

    /*/////////////////////////////////////////////////////////////
                    CHECK PARTICIPATION SIGNATURE  
    /////////////////////////////////////////////////////////////*/
    function testShouldSucceedForValidSignature()
        public
        getTheLastestDeployedSaleAndSetParams
        setRegistrationTimeAndTheSaleStartTime
    {
        bytes32 msgHash = keccak256(
            abi.encodePacked(INVESTOR, uint256(100 ether), address(sale))
        );
        bytes32 ethSignedMsgHash = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", msgHash)
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(accountPK, ethSignedMsgHash);
        bytes memory sig = abi.encodePacked(r, s, v);

        bool expectedCheckParticipationSignatureResult = sale
            .checkParticipationSignature(sig, INVESTOR, 100 ether);
        assertEq(expectedCheckParticipationSignatureResult, true);
    }
}
