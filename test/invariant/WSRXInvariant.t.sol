// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {WSRX} from "../../contracts/WSRX.sol";

contract WSRXHandler is Test {
    WSRX public wsrx;
    uint256 public ghost_deposited;
    uint256 public ghost_withdrawn;
    address[] internal actors;

    constructor(WSRX _wsrx) {
        wsrx = _wsrx;
        for (uint256 i = 0; i < 4; i++) {
            address a = address(uint160(uint256(keccak256(abi.encode("actor", i)))));
            vm.deal(a, 1_000_000 ether);
            actors.push(a);
        }
    }

    function deposit(uint256 amountSeed, uint256 actorSeed) public {
        address a = actors[actorSeed % actors.length];
        uint256 amount = bound(amountSeed, 0, 100 ether);
        if (a.balance < amount) return;
        vm.prank(a);
        wsrx.deposit{value: amount}();
        ghost_deposited += amount;
    }

    function withdraw(uint256 amountSeed, uint256 actorSeed) public {
        address a = actors[actorSeed % actors.length];
        uint256 bal = wsrx.balanceOf(a);
        if (bal == 0) return;
        uint256 amount = bound(amountSeed, 1, bal);
        vm.prank(a);
        wsrx.withdraw(amount);
        ghost_withdrawn += amount;
    }
}

contract WSRXInvariantTest is Test {
    WSRX wsrx;
    WSRXHandler handler;

    function setUp() public {
        wsrx = new WSRX();
        handler = new WSRXHandler(wsrx);
        targetContract(address(handler));
    }

    /// totalSupply == net deposited (deposits − withdrawals)
    function invariant_supply_matches_net_deposits() public view {
        assertEq(wsrx.totalSupply(), handler.ghost_deposited() - handler.ghost_withdrawn());
    }

    /// Contract's native balance must always cover totalSupply
    function invariant_native_balance_covers_supply() public view {
        assertGe(address(wsrx).balance, wsrx.totalSupply());
    }
}
