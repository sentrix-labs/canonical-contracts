// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {WSRX} from "../contracts/WSRX.sol";

contract WSRXTest is Test {
    WSRX wsrx;
    address alice = address(0xA11CE);
    address bob = address(0xB0B);

    function setUp() public {
        wsrx = new WSRX();
        vm.deal(alice, 100 ether);
        vm.deal(bob, 10 ether);
    }

    function test_deposit_increases_balance_and_supply() public {
        vm.prank(alice);
        wsrx.deposit{value: 5 ether}();
        assertEq(wsrx.balanceOf(alice), 5 ether);
        assertEq(wsrx.totalSupply(), 5 ether);
    }

    function test_deposit_via_receive() public {
        vm.prank(alice);
        (bool ok, ) = address(wsrx).call{value: 3 ether}("");
        assertTrue(ok);
        assertEq(wsrx.balanceOf(alice), 3 ether);
    }

    function test_withdraw_burns_and_returns_native() public {
        vm.prank(alice);
        wsrx.deposit{value: 5 ether}();

        uint256 nativeBalBefore = alice.balance;
        vm.prank(alice);
        wsrx.withdraw(2 ether);

        assertEq(wsrx.balanceOf(alice), 3 ether);
        assertEq(wsrx.totalSupply(), 3 ether);
        assertEq(alice.balance, nativeBalBefore + 2 ether);
    }

    function test_withdraw_reverts_on_insufficient_balance() public {
        vm.expectRevert(bytes("WSRX: insufficient balance"));
        vm.prank(alice);
        wsrx.withdraw(1 ether);
    }

    function test_transfer_moves_balance() public {
        vm.startPrank(alice);
        wsrx.deposit{value: 5 ether}();
        wsrx.transfer(bob, 2 ether);
        vm.stopPrank();

        assertEq(wsrx.balanceOf(alice), 3 ether);
        assertEq(wsrx.balanceOf(bob), 2 ether);
    }

    function test_approve_and_transfer_from() public {
        vm.startPrank(alice);
        wsrx.deposit{value: 5 ether}();
        wsrx.approve(bob, 2 ether);
        vm.stopPrank();

        vm.prank(bob);
        wsrx.transferFrom(alice, bob, 2 ether);

        assertEq(wsrx.balanceOf(alice), 3 ether);
        assertEq(wsrx.balanceOf(bob), 2 ether);
        assertEq(wsrx.allowance(alice, bob), 0);
    }

    function test_max_allowance_does_not_decrement() public {
        vm.startPrank(alice);
        wsrx.deposit{value: 5 ether}();
        wsrx.approve(bob, type(uint256).max);
        vm.stopPrank();

        vm.prank(bob);
        wsrx.transferFrom(alice, bob, 1 ether);

        assertEq(wsrx.allowance(alice, bob), type(uint256).max);
    }
}
