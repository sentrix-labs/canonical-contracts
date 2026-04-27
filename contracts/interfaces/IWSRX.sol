// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

/// @title IWSRX
/// @author Sentrix Labs
/// @notice Wrapped SRX interface — wrap/unwrap native SRX into a 1:1 ERC-20.
interface IWSRX {
    event Transfer(address indexed src, address indexed dst, uint256 wad);
    event Approval(address indexed src, address indexed guy, uint256 wad);
    event Deposit(address indexed dst, uint256 wad);
    event Withdrawal(address indexed src, uint256 wad);

    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
    function totalSupply() external view returns (uint256);
    function balanceOf(address owner) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);

    /// @notice Wrap native SRX 1:1 into WSRX.
    function deposit() external payable;

    /// @notice Burn WSRX, return native SRX.
    /// @param wad Amount in wei (18-dec).
    function withdraw(uint256 wad) external;

    function approve(address guy, uint256 wad) external returns (bool);
    function transfer(address dst, uint256 wad) external returns (bool);
    function transferFrom(address src, address dst, uint256 wad) external returns (bool);
}
