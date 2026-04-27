// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

/// @title Wrapped SRX
/// @notice Wraps native SRX into an ERC-20 token (18 decimals at the EVM
///         boundary). 1 SRX = 10^10 wei due to native ledger using 8
///         decimals; conversion is handled by the EVM database adapter,
///         so `msg.value` here is already the wei amount and `wad` minted
///         equals `msg.value` 1:1.
/// @dev Standard wrapped-token pattern (mirror of WETH9). Self-contained,
///      no external imports — keeps the canonical-contracts repo
///      dependency-free. Compiles with solc 0.8.24, no SafeMath needed.
contract WSRX {
    string public constant name = "Wrapped SRX";
    string public constant symbol = "WSRX";
    uint8 public constant decimals = 18;

    uint256 public totalSupply;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    event Transfer(address indexed src, address indexed dst, uint256 wad);
    event Approval(address indexed src, address indexed guy, uint256 wad);
    event Deposit(address indexed dst, uint256 wad);
    event Withdrawal(address indexed src, uint256 wad);

    receive() external payable {
        deposit();
    }

    function deposit() public payable {
        balanceOf[msg.sender] += msg.value;
        totalSupply += msg.value;
        emit Deposit(msg.sender, msg.value);
        emit Transfer(address(0), msg.sender, msg.value);
    }

    function withdraw(uint256 wad) external {
        require(balanceOf[msg.sender] >= wad, "WSRX: insufficient balance");
        balanceOf[msg.sender] -= wad;
        totalSupply -= wad;
        (bool ok, ) = msg.sender.call{value: wad}("");
        require(ok, "WSRX: native transfer failed");
        emit Withdrawal(msg.sender, wad);
        emit Transfer(msg.sender, address(0), wad);
    }

    function approve(address guy, uint256 wad) external returns (bool) {
        allowance[msg.sender][guy] = wad;
        emit Approval(msg.sender, guy, wad);
        return true;
    }

    function transfer(address dst, uint256 wad) external returns (bool) {
        return _transferFrom(msg.sender, dst, wad);
    }

    function transferFrom(address src, address dst, uint256 wad) external returns (bool) {
        if (src != msg.sender) {
            uint256 allowed = allowance[src][msg.sender];
            if (allowed != type(uint256).max) {
                require(allowed >= wad, "WSRX: insufficient allowance");
                allowance[src][msg.sender] = allowed - wad;
            }
        }
        return _transferFrom(src, dst, wad);
    }

    function _transferFrom(address src, address dst, uint256 wad) internal returns (bool) {
        require(balanceOf[src] >= wad, "WSRX: insufficient balance");
        balanceOf[src] -= wad;
        balanceOf[dst] += wad;
        emit Transfer(src, dst, wad);
        return true;
    }
}
