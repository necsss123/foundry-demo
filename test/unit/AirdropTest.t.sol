// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {Deploy} from "../../script/Deploy.s.sol";
import {Airdrop} from "../../src/Airdrop.sol";
import {IceFrog} from "../../src/IceFrog.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";

contract AirdropTest is Test {
    /* Events */
    event TokensAirdropped(address indexed beneficiary);

    Deploy deployer;
    Airdrop airdrop;
    IceFrog icefrog;
    HelperConfig helperConfig;
    address account;
    address public USER = makeAddr("user");

    uint256 public constant FUND_AIRDROP = 10000 ether;

    function setUp() public {
        deployer = new Deploy();
        (icefrog, airdrop, , , helperConfig) = deployer.run();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig(
            block.chainid
        );
        account = config.defaultAccount;
        vm.prank(account);
        icefrog.transfer(address(airdrop), FUND_AIRDROP);
    }

    /*/////////////////////////////////////////////////////////////
                            CONSTRUCTOR  
    /////////////////////////////////////////////////////////////*/

    function testAirdropTokenIsInitializedToIF() public view {
        address expectedAddr = airdrop.getAirdropToken();
        address actualAddr = address(icefrog);
        assertEq(expectedAddr, actualAddr);
    }

    /*/////////////////////////////////////////////////////////////
                        WITHDRAW  TOKENS
    /////////////////////////////////////////////////////////////*/
    function testNonUserAddressCallsWithdrawTokensFunction() public {
        vm.expectRevert(Airdrop.Airdrop__NonUserCall.selector);
        airdrop.withdrawTokens();
    }

    function testAirdropTokenCanBeClaimedByUsers() public {
        vm.startPrank(USER, USER); // 让 msg.sender 和 tx.origin 都是 USER
        airdrop.withdrawTokens();
        vm.stopPrank();

        uint256 actualAmount = icefrog.balanceOf(USER);
        uint256 expectedAmount = airdrop.TOKENS_PER_CLAIM();
        assertEq(expectedAmount, actualAmount);
    }

    function testOneUserAddressCanOnlyClaimOneAirdrop() public {
        vm.startPrank(USER, USER);
        airdrop.withdrawTokens();
        vm.expectRevert(Airdrop.Airdrop__AlreadyClaimed.selector);
        airdrop.withdrawTokens();
        vm.stopPrank();
    }

    function testEmitsEventOnWithdrawSuccess() public {
        vm.startPrank(USER, USER);
        vm.expectEmit(true, false, false, true, address(airdrop));
        emit TokensAirdropped(USER);
        airdrop.withdrawTokens();
        vm.stopPrank();
    }
}
