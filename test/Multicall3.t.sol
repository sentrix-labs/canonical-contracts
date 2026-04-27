// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {Multicall3} from "../contracts/Multicall3.sol";

contract MulticallTarget {
    uint256 public counter;
    function bump() external returns (uint256) { counter += 1; return counter; }
    function getCounter() external view returns (uint256) { return counter; }
    function fail() external pure { revert("intentional"); }
}

contract Multicall3Test is Test {
    Multicall3 mc;
    MulticallTarget target;

    function setUp() public {
        mc = new Multicall3();
        target = new MulticallTarget();
    }

    function test_aggregate_two_views() public {
        Multicall3.Call[] memory calls = new Multicall3.Call[](2);
        calls[0] = Multicall3.Call(address(target), abi.encodeWithSignature("getCounter()"));
        calls[1] = Multicall3.Call(address(target), abi.encodeWithSignature("getCounter()"));

        (uint256 blockNumber, bytes[] memory ret) = mc.aggregate(calls);
        assertEq(blockNumber, block.number);
        assertEq(ret.length, 2);
        assertEq(abi.decode(ret[0], (uint256)), 0);
    }

    function test_aggregate3_with_failure_allowed() public {
        Multicall3.Call3[] memory calls = new Multicall3.Call3[](2);
        calls[0] = Multicall3.Call3(address(target), false, abi.encodeWithSignature("bump()"));
        calls[1] = Multicall3.Call3(address(target), true, abi.encodeWithSignature("fail()"));

        Multicall3.Result[] memory ret = mc.aggregate3(calls);
        assertTrue(ret[0].success);
        assertFalse(ret[1].success);
    }

    function test_helpers() public {
        assertEq(mc.getBlockNumber(), block.number);
        assertEq(mc.getChainId(), block.chainid);
    }
}
