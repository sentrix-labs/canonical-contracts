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
}
