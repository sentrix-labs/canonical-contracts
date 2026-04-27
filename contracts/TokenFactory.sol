// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

/// @title Sentrix TokenFactory
/// @notice Deploys standard ERC-20 tokens. Single entry point for builders
///         who want a fungible token without writing Solidity. Initial
///         supply is minted to the deployer (`msg.sender`).
/// @dev Tracks deployed-token-by-deployer to make discovery easy.
contract TokenFactory {
    event TokenDeployed(address indexed token, address indexed owner, string name, string symbol, uint256 initialSupply);

    mapping(address => address[]) public deployedTokens;

    function deployToken(string calldata name, string calldata symbol, uint256 initialSupply) external returns (address token) {
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
        require(balanceOf[from] >= amount, "FactoryToken: insufficient balance");
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        emit Transfer(from, to, amount);
        return true;
    }
}
