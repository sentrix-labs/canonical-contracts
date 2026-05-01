// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {TokenFactory, FactoryToken} from "../../contracts/TokenFactory.sol";

contract FactoryFuzzTest is Test {
    TokenFactory factory;

    function setUp() public {
        factory = new TokenFactory();
    }

    function testFuzz_deploy_with_supply(uint256 supply, address owner) public {
        vm.assume(owner != address(0));
        // Floor at 1 — the audit-added ZERO_SUPPLY guard rejects 0.
        supply = bound(supply, 1, type(uint128).max);
        vm.prank(owner);
        address t = factory.deployToken("FuzzT", "FT", supply);
        FactoryToken ft = FactoryToken(t);
        assertEq(ft.totalSupply(), supply);
        assertEq(ft.balanceOf(owner), supply);
    }

    function testFuzz_deploy_records_in_mapping(uint8 deployCount, address owner) public {
        vm.assume(owner != address(0));
        deployCount = uint8(bound(deployCount, 1, 10));
        for (uint256 i = 0; i < deployCount; i++) {
            vm.prank(owner);
            factory.deployToken("X", "X", 1);
        }
        assertEq(factory.tokenCount(owner), deployCount);
        assertEq(factory.tokensOf(owner).length, deployCount);
    }

    function testFuzz_token_transfer_preserves_supply(uint256 supply, uint256 amt) public {
        supply = bound(supply, 1, type(uint128).max);
        amt = bound(amt, 0, supply);
        address alice = address(0xA);
        address bob = address(0xB);
        vm.prank(alice);
        FactoryToken t = FactoryToken(factory.deployToken("T", "T", supply));
        vm.prank(alice);
        t.transfer(bob, amt);
        assertEq(t.balanceOf(alice) + t.balanceOf(bob), supply);
        assertEq(t.totalSupply(), supply);
    }
}
