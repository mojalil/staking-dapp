// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

contract CustomToken {
    string public name = "Custom Token";
    string public symbol = "CT";
    string public standard = "Custom Token v1.0";
    uint256 public totalSupply;
    address public ownerOfContract;
    uint256 public _userId;

    address[] public holderToken;

    event Transfer(address indexed _from, address indexed _to, uint256 _value);

    event Approval(address indexed _owner, address indexed _spender, uint256 _value);

    mapping (address => TokenHolderInfo) public tokenHolderInfo;

    struct TokenHolderInfo {
        uint256 _tokenId;
        address _from;
        address _to;
        uint _totalToken;
        bool _tokenHolder;
    }

    mapping (address => uint256) public balanceOf;
    mapping (address => mapping (address => uint256)) public allowance;

    constructor(uint256 _initialSupply) {
        totalSupply = _initialSupply;
        balanceOf[msg.sender] = totalSupply;
        ownerOfContract = msg.sender;
    }

    function inc() internal {
        _userId++;
    }

    function transfer(address _to, uint256 _value) public returns (bool success) {
        require(balanceOf[msg.sender] >= _value, "Not enough balance");
        require(_to != address(0), "Invalid address");

        balanceOf[msg.sender] -= _value;
        balanceOf[_to] += _value;

        TokenHolderInfo storage tokenHolder = tokenHolderInfo[_to];
        tokenHolder._tokenId = _userId;
        tokenHolder._from = msg.sender;
        tokenHolder._to = _to;
        tokenHolder._totalToken = _value;
        tokenHolder._tokenHolder = true;

        holderToken.push(_to);

        inc();

        emit Transfer(msg.sender, _to, _value);
        return true;
    }

    function approve(address _spender, uint256 _value) public returns (bool success) {
        allowance[msg.sender][_spender] = _value;

        emit Approval(msg.sender, _spender, _value);
        return true;
    }

    function transferFrom(
        address _from,
        address _to,
        uint256 _value
    ) public returns (bool success) {
        require(_value <= balanceOf[_from], "Not enough balance");
        require(_value <= allowance[_from][msg.sender], "Not enough allowance");
        require(_to != address(0), "Invalid address");

        balanceOf[_from] -= _value;
        balanceOf[_to] += _value;

        allowance[_from][msg.sender] -= _value;

        emit Transfer(_from, _to, _value);
        return true;
    }

    function getTokenHolderData(address _holder) public view returns (
        uint256 _tokenId,
        address _from,
        address _to,
        uint _totalToken,
        bool _tokenHolder
    ) {

        TokenHolderInfo storage tokenHolder = tokenHolderInfo[_holder];
        return (
            tokenHolder._tokenId,
            tokenHolder._from,
            tokenHolder._to,
            tokenHolder._totalToken,
            tokenHolder._tokenHolder
        );
    }
    
}