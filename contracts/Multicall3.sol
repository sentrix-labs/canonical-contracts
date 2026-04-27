// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @title Multicall3
/// @notice Aggregate read/write contract calls into a single tx.
/// @dev Mirror of github.com/mds1/multicall (canonical address
///      0xcA11bde05977b3631167028862bE2a173976CA11 across most chains).
///      Reproduced here verbatim to keep the canonical-contracts repo
///      self-contained. License preserved (MIT — owner: Matt Solomon).
contract Multicall3 {
    struct Call {
        address target;
        bytes callData;
    }

    struct Call3 {
        address target;
        bool allowFailure;
        bytes callData;
    }

    struct Call3Value {
        address target;
        bool allowFailure;
        uint256 value;
        bytes callData;
    }

    struct Result {
        bool success;
        bytes returnData;
    }

    /// @notice Backwards-compatible aggregate (reverts on any failure).
    function aggregate(Call[] calldata calls) external payable returns (uint256 blockNumber, bytes[] memory returnData) {
        blockNumber = block.number;
        uint256 length = calls.length;
        returnData = new bytes[](length);
        Call calldata call;
        for (uint256 i = 0; i < length; ) {
            bool success;
            call = calls[i];
            (success, returnData[i]) = call.target.call(call.callData);
            require(success, "Multicall3: call failed");
            unchecked { ++i; }
        }
    }

    /// @notice Aggregate calls; per-call failure mode controllable.
    function aggregate3(Call3[] calldata calls) external payable returns (Result[] memory returnData) {
        uint256 length = calls.length;
        returnData = new Result[](length);
        Call3 calldata calli;
        for (uint256 i = 0; i < length; ) {
            Result memory result = returnData[i];
            calli = calls[i];
            (result.success, result.returnData) = calli.target.call(calli.callData);
            assembly {
                if iszero(or(calldataload(add(calli, 0x20)), mload(result))) {
                    mstore(0x00, 0x08c379a0)
                    mstore(0x20, 0x20)
                    mstore(0x40, 0x17)
                    mstore(0x60, 0x4d756c746963616c6c333a2063616c6c206661696c6564000000000000000000)
                    revert(0x1c, 0x64)
                }
            }
            unchecked { ++i; }
        }
    }

    /// @notice Aggregate calls with values; per-call failure mode controllable.
    function aggregate3Value(Call3Value[] calldata calls) external payable returns (Result[] memory returnData) {
        uint256 valAccumulator;
        uint256 length = calls.length;
        returnData = new Result[](length);
        Call3Value calldata calli;
        for (uint256 i = 0; i < length; ) {
            Result memory result = returnData[i];
            calli = calls[i];
            uint256 val = calli.value;
            unchecked { valAccumulator += val; }
            (result.success, result.returnData) = calli.target.call{value: val}(calli.callData);
            assembly {
                if iszero(or(calldataload(add(calli, 0x40)), mload(result))) {
                    mstore(0x00, 0x08c379a0)
                    mstore(0x20, 0x20)
                    mstore(0x40, 0x17)
                    mstore(0x60, 0x4d756c746963616c6c333a2063616c6c206661696c6564000000000000000000)
                    revert(0x1c, 0x64)
                }
            }
            unchecked { ++i; }
        }
        require(msg.value == valAccumulator, "Multicall3: value mismatch");
    }

    function blockAndAggregate(Call[] calldata calls) external payable returns (uint256 blockNumber, bytes32 blockHash, Result[] memory returnData) {
        (blockNumber, blockHash, returnData) = tryBlockAndAggregate(calls);
    }

    function tryBlockAndAggregate(Call[] calldata calls) public payable returns (uint256 blockNumber, bytes32 blockHash, Result[] memory returnData) {
        blockNumber = block.number;
        blockHash = blockhash(block.number);
        uint256 length = calls.length;
        returnData = new Result[](length);
        Call calldata call;
        for (uint256 i = 0; i < length; ) {
            Result memory result = returnData[i];
            call = calls[i];
            (result.success, result.returnData) = call.target.call(call.callData);
            unchecked { ++i; }
        }
    }

    function getBlockNumber() external view returns (uint256) { return block.number; }
    function getBlockHash(uint256 blockNumber) external view returns (bytes32) { return blockhash(blockNumber); }
    function getCurrentBlockTimestamp() external view returns (uint256) { return block.timestamp; }
    function getCurrentBlockGasLimit() external view returns (uint256) { return block.gaslimit; }
    function getCurrentBlockCoinbase() external view returns (address) { return block.coinbase; }
    function getEthBalance(address addr) external view returns (uint256) { return addr.balance; }
    function getLastBlockHash() external view returns (bytes32) { return blockhash(block.number - 1); }
    function getChainId() external view returns (uint256) { return block.chainid; }
    function getBasefee() external view returns (uint256) { return block.basefee; }
}
