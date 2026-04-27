// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

/// @title MockSRX
/// @author Sentrix Labs
/// @notice Test-only payable contract that simulates a native-SRX holder.
///         Lets tests send native value into and out of a known contract
///         without involving the real chain. Use only in test/.
contract MockSRX {
    event Received(address indexed from, uint256 amount);
    event Forwarded(address indexed to, uint256 amount);

    receive() external payable {
        emit Received(msg.sender, msg.value);
    }

    /// @notice Forward held native SRX to `to`. Test helper only.
    function forward(address payable to, uint256 amount) external {
        require(address(this).balance >= amount, "MockSRX: insufficient");
        (bool ok, ) = to.call{value: amount}("");
        require(ok, "MockSRX: forward failed");
        emit Forwarded(to, amount);
    }

    function balance() external view returns (uint256) {
        return address(this).balance;
    }
}
