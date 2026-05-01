// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

/// @title Sentrix TokenFactory
/// @author Sentrix Labs
/// @notice Deploys standard ERC-20 tokens. Single entry point for builders
///         who want a fungible token without writing Solidity. Initial
///         supply is minted to the deployer (`msg.sender`).
/// @dev Tracks deployed-token-by-deployer to make discovery easy.
contract TokenFactory {
    event TokenDeployed(address indexed token, address indexed owner, string name, string symbol, uint256 initialSupply);

    /// @dev Caps name/symbol bytes to prevent gas-grief deploys with megabyte
    ///      strings. Standard ERC20 metadata fits comfortably under both caps.
    uint256 public constant MAX_NAME_LENGTH = 64;
    uint256 public constant MAX_SYMBOL_LENGTH = 16;

    mapping(address => address[]) public deployedTokens;

    function deployToken(string calldata name, string calldata symbol, uint256 initialSupply) external returns (address token) {
        // Reject silly inputs early — a zero-supply or empty-name token is
        // never useful and burns gas for everyone indexing the event log.
        require(initialSupply > 0, "TokenFactory: ZERO_SUPPLY");
        require(bytes(name).length > 0 && bytes(name).length <= MAX_NAME_LENGTH, "TokenFactory: BAD_NAME");
        require(bytes(symbol).length > 0 && bytes(symbol).length <= MAX_SYMBOL_LENGTH, "TokenFactory: BAD_SYMBOL");

        FactoryToken t = new FactoryToken(name, symbol, initialSupply, msg.sender);
        token = address(t);
        deployedTokens[msg.sender].push(token);
        emit TokenDeployed(token, msg.sender, name, symbol, initialSupply);
    }

    function tokensOf(address owner) external view returns (address[] memory) {
        return deployedTokens[owner];
    }

    function tokenCount(address owner) external view returns (uint256) {
        return deployedTokens[owner].length;
    }
}

/// @notice Minimal ERC-20 deployed by the factory.
contract FactoryToken {
    string public name;
    string public symbol;
    uint8 public constant decimals = 18;
    uint256 public totalSupply;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    constructor(string memory _name, string memory _symbol, uint256 _initialSupply, address _owner) {
        name = _name;
        symbol = _symbol;
        totalSupply = _initialSupply;
        balanceOf[_owner] = _initialSupply;
        emit Transfer(address(0), _owner, _initialSupply);
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        return _transfer(msg.sender, to, amount);
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        if (from != msg.sender) {
            uint256 allowed = allowance[from][msg.sender];
            if (allowed != type(uint256).max) {
                require(allowed >= amount, "FactoryToken: insufficient allowance");
                allowance[from][msg.sender] = allowed - amount;
            }
        }
        return _transfer(from, to, amount);
    }

    function _transfer(address from, address to, uint256 amount) internal returns (bool) {
        // ERC-20 spec says transfers to address(0) are not standard burns —
        // most token contracts revert. Be explicit so wallets that show a
        // failed tx instead of an unexpected `Transfer(... 0x0 ...)` log.
        require(to != address(0), "FactoryToken: TO_ZERO");
        require(balanceOf[from] >= amount, "FactoryToken: insufficient balance");
        unchecked {
            balanceOf[from] -= amount;
            balanceOf[to] += amount;
        }
        emit Transfer(from, to, amount);
        return true;
    }
}
