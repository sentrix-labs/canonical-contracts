// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {TokenFactory, FactoryToken} from "../contracts/TokenFactory.sol";

contract FactoryTest is Test {
    TokenFactory factory;
    address alice = address(0xA11CE);
    address bob = address(0xB0B);

    function setUp() public {
        factory = new TokenFactory();
    }

    function test_deploy_token_mints_to_caller() public {
        vm.prank(alice);
        address token = factory.deployToken("Test", "TST", 1000 ether);

        FactoryToken t = FactoryToken(token);
        assertEq(t.name(), "Test");
        assertEq(t.symbol(), "TST");
        assertEq(t.totalSupply(), 1000 ether);
        assertEq(t.balanceOf(alice), 1000 ether);
    }

    function test_deployed_tokens_tracked_per_owner() public {
        vm.startPrank(alice);
        address t1 = factory.deployToken("A", "A", 1);
        address t2 = factory.deployToken("B", "B", 1);
        vm.stopPrank();

        assertEq(factory.tokenCount(alice), 2);
        address[] memory all = factory.tokensOf(alice);
        assertEq(all[0], t1);
        assertEq(all[1], t2);
    }

    function test_factory_token_transfer_and_approve() public {
        vm.prank(alice);
        address token = factory.deployToken("Test", "TST", 1000 ether);
        FactoryToken t = FactoryToken(token);

        vm.prank(alice);
        t.transfer(bob, 100 ether);
        assertEq(t.balanceOf(bob), 100 ether);
        assertEq(t.balanceOf(alice), 900 ether);

        vm.prank(bob);
        t.approve(alice, 50 ether);
        assertEq(t.allowance(bob, alice), 50 ether);

        vm.prank(alice);
        t.transferFrom(bob, alice, 50 ether);
        assertEq(t.balanceOf(bob), 50 ether);
    }

    // ── Input-validation tests added 2026-04-30 audit pass ───────────

    function test_deploy_rejects_zero_supply() public {
        vm.prank(alice);
        vm.expectRevert(bytes("TokenFactory: ZERO_SUPPLY"));
        factory.deployToken("X", "X", 0);
    }

    function test_deploy_rejects_empty_name() public {
        vm.prank(alice);
        vm.expectRevert(bytes("TokenFactory: BAD_NAME"));
        factory.deployToken("", "X", 1);
    }

    function test_deploy_rejects_empty_symbol() public {
        vm.prank(alice);
        vm.expectRevert(bytes("TokenFactory: BAD_SYMBOL"));
        factory.deployToken("X", "", 1);
    }

    function test_deploy_rejects_oversize_name() public {
        // 65-char name (cap is 64)
        string memory longName = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA";
        vm.prank(alice);
        vm.expectRevert(bytes("TokenFactory: BAD_NAME"));
        factory.deployToken(longName, "X", 1);
    }

    function test_deploy_rejects_oversize_symbol() public {
        // 17-char symbol (cap is 16)
        string memory longSym = "AAAAAAAAAAAAAAAAA";
        vm.prank(alice);
        vm.expectRevert(bytes("TokenFactory: BAD_SYMBOL"));
        factory.deployToken("X", longSym, 1);
    }

    function test_factory_token_transfer_to_zero_reverts() public {
        vm.prank(alice);
        address token = factory.deployToken("Test", "TST", 1000 ether);
        FactoryToken t = FactoryToken(token);

        vm.prank(alice);
        vm.expectRevert(bytes("FactoryToken: TO_ZERO"));
        t.transfer(address(0), 1);
    }
}
