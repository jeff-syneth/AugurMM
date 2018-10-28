pragma solidity ^0.4.25;

contract Token {
    function totalSupply() public view returns (uint256) {}
    function balanceOf(address _owner) public view returns (uint256 balance) {}
    function transfer(address _to, uint256 _value) public returns (bool success) {}
    function transferFrom(address _from, address _to, uint256 _value) public returns (bool success) {}
    function approve(address _spender, uint256 _value) public returns (bool success) {}
    function allowance(address _owner, address _spender) public view returns (uint256 remaining) {}
    
    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);
}

contract CancelOrder {
    function cancelOrder(bytes32 _orderId) external returns (bool) {}
}

contract ClaimTradingProceeds {
    
}

contract Orders {
    function getOrderSharesEscrowed(bytes32 _orderId) public view returns (uint256) {}
    function getOrderMoneyEscrowed(bytes32 _orderId) public view returns (uint256) {}
    function getMarket(bytes32 _orderId) public view returns (IMarket) {}
}

contract owned {
    address public owner;
    
    constructor() public {
        owner = msg.sender;
    }
    
    modifier onlyOwner {
        require(msg.sender==owner);
        _;
    }
    
    function transferOwnership(address newOwner) public onlyOwner {
        owner = newOwner;
    }
}

contract AugurMM is owned {
    struct Member {
        address addr;
        uint weiamount;
    }
    
    uint public totalcontributed;
    uint public joinMin;
    uint public addMin;
    Token[] public listOfTokens;
    CancelOrder public cancelOrderObj;
    ClaimTradingProceeds public claimTradingObj;
    Orders public ordersObj;
    Member[] public members;
    uint startTime;
    uint[] limitUsed;
    
    constructor() public {
        members.push(Member(msg.sender,0));
        joinMin = 0.1 ether;
        addMin = 0.01 ether;
        cancelOrderObj = CancelOrder(0x3448209268e97652bb67ea12777d4dfba81e3aaf);
        claimTradingObj = ClaimTradingProceeds(0x4334477348222a986fc88a05410aa6b07507872a);
        ordersObj = Orders(0xd7a14019aeeba25e676a1b596bb19b6f37db74d2);
        startTime = now;
    }
    
    function setJoinMin(uint newValue) public onlyOwner {
        joinMin = newValue;
    }
    
    function setAddMin(uint newValue) public onlyOwner {
        addMin = newValue;
    }
    
    function join() public payable {
        require(msg.value >= joinMin);
        members.push(Member(msg.sender,msg.value));
        totalcontributed += msg.value;
    }
    
    function contributeMore(uint addrindex) public payable {
        require(msg.value >= addMin);
        require(members[addrindex].addr == msg.sender);
        members[addrindex].weiamount += msg.value;
        totalcontributed += msg.value;
    }
    
    function withdraw(uint amount, uint addrindex) public { //Unqualified withdrawal
        require(members[addrindex].addr == msg.sender);
        require(amount <= members[addrindex].weiamount);
        members[addrindex].weiamount -= amount;
        uint[listOfTokens.length+1] transferAmounts;
        transferAmounts[0] = this.balance * amount / totalcontributed;
        for (uint i=0;i<listOfTokens.length;i++) {
            transferAmounts[i+1] = listOfTokens[i].balanceOf(this) * amount / totalcontributed;
        }
        totalcontributed -= amount;
        msg.sender.transfer(transferAmounts[0]);
        for (uint i=0;i<listOfTokens.length;i++) {
            listOfTokens[i].transfer(msg.sender, transferAmounts[i+1]);
        }
    }
    
    function withdrawPick(uint amount, uint addrindex, uint[] tokens) external {
        require(members[addrindex].addr == msg.sender);
        require(amount <= members[addrindex].weiamount);
        members[addrindex].weiamount -= amount;
        uint[tokens.length+1] transferAmounts;
        Token[tokens.length] actualTokens;
        transferAmounts[0] = this.balance * amount / totalcontributed;
        for (uint i=0;i<tokens.length;i++) {
            actualTokens[i] = listOfTokens[tokens[i]];
            transferAmounts[i+1] = actualTokens[i].balanceOf(this) * amount / totalcontributed;
        }
        totalcontributed -= amount;
        msg.sender.transfer(transferAmounts[0]);
        for (uint i=0;i<actualTokens.length;i++) {
            actualTokens[i].transfer(msg.sender,transferAmounts[i+1]);
        }
    }
    
    function augurCancelOrder(bytes32 id) public onlyOwner {
        uint cashFreedUp = ordersObj.getOrderMoneyEscrowed(id);
        uint sharesFreedUp = ordersObj.getOrderSharesEscrowed(id); //shares are assumed to be worth maximal value ie. numTicks attoETH/SHARE
        uint totalLimitFreed = cashFreedUp + ordersObj.getMarket(id).getNumTicks() * sharesFreedUp;
        while(limitUsed.length < (now-startTime)/(1 days)+1) {
            limitUsed.push(0);
        }
        limitUsed[(now-startTime)/(1 days)] -= totalLimitFreed;
        cancelOrderObj.cancelOrder(id);
    }
}