// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {WSRX} from "../../contracts/WSRX.sol";

contract WSRXFuzzTest is Test {
    WSRX wsrx;
    address alice = address(0xA11CE);

    function setUp() public {
        wsrx = new WSRX();
    }

    function testFuzz_deposit_credits_full_amount(uint256 amount) public {
        amount = bound(amount, 0, 1_000_000 ether);
        vm.deal(alice, amount);
        vm.prank(alice);
        wsrx.deposit{value: amount}();
        assertEq(wsrx.balanceOf(alice), amount);
        assertEq(wsrx.totalSupply(), amount);
    }

    function testFuzz_withdraw_round_trip(uint256 amount) public {
        amount = bound(amount, 1, 1_000_000 ether);
        vm.deal(alice, amount);
        vm.startPrank(alice);
        wsrx.deposit{value: amount}();
        wsrx.withdraw(amount);
        vm.stopPrank();
        assertEq(wsrx.balanceOf(alice), 0);
        assertEq(wsrx.totalSupply(), 0);
        assertEq(alice.balance, amount);
    }

    function testFuzz_partial_withdraw(uint256 deposited, uint256 withdrawn) public {
        deposited = bound(deposited, 1, 1_000_000 ether);
        withdrawn = bound(withdrawn, 0, deposited);
        vm.deal(alice, deposited);
        vm.startPrank(alice);
        wsrx.deposit{value: deposited}();
        if (withdrawn > 0) wsrx.withdraw(withdrawn);
        vm.stopPrank();
        assertEq(wsrx.balanceOf(alice), deposited - withdrawn);
    }
}
