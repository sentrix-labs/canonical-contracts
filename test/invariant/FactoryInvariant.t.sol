// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {TokenFactory} from "../../contracts/TokenFactory.sol";

contract FactoryHandler is Test {
    TokenFactory public factory;
    address[] public actors;
    uint256 public ghost_total_deploys;

    constructor(TokenFactory _f) {
        factory = _f;
        for (uint256 i = 0; i < 4; i++) {
            actors.push(address(uint160(uint256(keccak256(abi.encode("a", i))))));
        }
    }

    function deploy(uint256 actorSeed, uint256 supplySeed) public {
        address a = actors[actorSeed % actors.length];
        uint256 supply = bound(supplySeed, 1, 1_000_000 ether);
        vm.prank(a);
        factory.deployToken("X", "X", supply);
        ghost_total_deploys++;
    }
}

contract FactoryInvariantTest is Test {
    TokenFactory factory;
    FactoryHandler handler;

    function setUp() public {
        factory = new TokenFactory();
        handler = new FactoryHandler(factory);
        targetContract(address(handler));
    }

    /// Sum of `tokenCount(actor)` across all actors must equal total deploys
    function invariant_all_deploys_tracked() public view {
        uint256 sum;
        for (uint256 i = 0; i < 4; i++) {
            sum += factory.tokenCount(handler.actors(i));
        }
        assertEq(sum, handler.ghost_total_deploys());
    }
}
