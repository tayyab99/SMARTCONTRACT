/**********************************************************************
*These solidity codes have been obtained from Etherscan for extracting
*the smartcontract related info.
*The data will be used by MATRIX AI team as the reference basis for
*MATRIX model analysis,extraction of contract semantics,
*as well as AI based data analysis, etc.
**********************************************************************/
pragma solidity ^0.4.13;
library SafeMath {    
  function mul(uint256 a, uint256 b) internal pure returns (uint256) {
    uint256 c = a * b;
    assert(a == 0 || c / a == b);
    return c;
  }
  function div(uint256 a, uint256 b) internal pure returns (uint256) {
    uint256 c = a / b;
    return c;
  } 
  function sub(uint256 a, uint256 b) internal pure returns (uint256) {
    assert(b <= a);
    return a - b;
  } 
  function add(uint256 a, uint256 b) internal pure returns (uint256) {
    uint256 c = a + b;
    assert(c >= a);
    return c;
  }  
}

contract ERC20Basic {
  uint256 public totalSupply;
  function balanceOf(address who) public constant returns (uint256);
  function transfer(address to, uint256 value) public returns (bool);
  event Transfer(address indexed from, address indexed to, uint256 value);
  event Burn(address indexed burner, uint256 value);
}

contract ERC20 is ERC20Basic {
  function allowance(address owner, address spender) public constant returns (uint256);
  function transferFrom(address from, address to, uint256 value) public returns (bool);
  function approve(address spender, uint256 value) public returns (bool);
  event Approval(address indexed owner, address indexed spender, uint256 value);
}

contract BasicToken is ERC20Basic {
  
  using SafeMath for uint256;
  bool public teamStakesFrozen = true;
  bool public fundariaStakesFrozen = true;
  mapping(address => uint256) balances;
  address public owner;
  address public fundaria = 0x1882464533072e9fCd8C6D3c5c5b588548B95296; // initial Fundaria pool address  
  
  function BasicToken() public {
    owner = msg.sender;
  }
  
  modifier notFrozen() {
    require(msg.sender != owner || (msg.sender == owner && !teamStakesFrozen) || (msg.sender == fundaria && !fundariaStakesFrozen));
    _;
  }

  /**
  * @dev transfer token for a specified address
  * @param _to The address to transfer to.
  * @param _value The amount to be transferred.
  */
  function transfer(address _to, uint256 _value) public notFrozen returns (bool) {
    require(_to != address(0));
    require(_value <= balances[msg.sender]);
    // SafeMath.sub will throw if there is not enough balance.
    balances[msg.sender] = balances[msg.sender].sub(_value);
    balances[_to] = balances[_to].add(_value);
    Transfer(msg.sender, _to, _value);
    return true;
  }

  /**
  * @dev Gets the balance of the specified address.
  * @param _owner The address to query the the balance of.
  * @return An uint256 representing the amount owned by the passed address.
  */
  function balanceOf(address _owner) public constant returns (uint256 balance) {
    return balances[_owner];
  }
}

contract StandardToken is ERC20, BasicToken {
  mapping (address => mapping (address => uint256)) internal allowed;
  /**
   * @dev Transfer tokens from one address to another
   * @param _from address The address which you want to send tokens from
   * @param _to address The address which you want to transfer to
   * @param _value uint256 the amount of tokens to be transferred
   */
  function transferFrom(address _from, address _to, uint256 _value) public returns (bool) {
    require(_to != address(0));
    require(_value <= balances[_from]);
    require(_value <= allowed[_from][msg.sender]);
    balances[_from] = balances[_from].sub(_value);
    balances[_to] = balances[_to].add(_value);
    allowed[_from][msg.sender] = allowed[_from][msg.sender].sub(_value);
    Transfer(_from, _to, _value);
    return true;
  }

  /**
   * @dev Approve the passed address to spend the specified amount of tokens on behalf of msg.sender.
   *
   * Beware that changing an allowance with this method brings the risk that someone may use both the old
   * and the new allowance by unfortunate transaction ordering. One possible solution to mitigate this
   * race condition is to first reduce the spender's allowance to 0 and set the desired value afterwards:
   * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
   * @param _spender The address which will spend the funds.
   * @param _value The amount of tokens to be spent.
   */
  function approve(address _spender, uint256 _value) public notFrozen returns (bool) {
    allowed[msg.sender][_spender] = _value;
    Approval(msg.sender, _spender, _value);
    return true;
  }

  /**
   * @dev Function to check the amount of tokens that an owner allowed to a spender.
   * @param _owner address The address which owns the funds.
   * @param _spender address The address which will spend the funds.
   * @return A uint256 specifying the amount of tokens still available for the spender.
   */
  function allowance(address _owner, address _spender) public constant returns (uint256 remaining) {
    return allowed[_owner][_spender];
  }

  /**
   * approve should be called when allowed[_spender] == 0. To increment
   * allowed value is better to use this function to avoid 2 calls (and wait until
   * the first transaction is mined)
   * From MonolithDAO Token.sol
   */
  function increaseApproval (address _spender, uint _addedValue) public notFrozen returns (bool success) {
    allowed[msg.sender][_spender] = allowed[msg.sender][_spender].add(_addedValue);
    Approval(msg.sender, _spender, allowed[msg.sender][_spender]);
    return true;
  }

  function decreaseApproval (address _spender, uint _subtractedValue) public returns (bool success) {
    uint oldValue = allowed[msg.sender][_spender];
    if (_subtractedValue > oldValue) {
      allowed[msg.sender][_spender] = 0;
    } else {
      allowed[msg.sender][_spender] = oldValue.sub(_subtractedValue);
    }
    Approval(msg.sender, _spender, allowed[msg.sender][_spender]);
    return true;
  }
}

contract SAUR is StandardToken {
  string public constant name = "Cardosaur Stake";
  string public constant symbol = "SAUR";
  uint8 public constant decimals = 0;
}

contract Sale is SAUR {

    using SafeMath for uint;

/********** 
 * Common *
 **********/

    // THIS IS KEY VARIABLE AND DEFINED ACCORDING TO VALUE OF PLANNED COSTS ON THE PAGE https://business.fundaria.com
    uint public poolCapUSD = 70000; // 70000 initially
    // USD per 1 ether, added 10% aproximatelly to secure from wrong low price. We need add 10% of Stakes to supply to cover such price.
    uint public usdPerEther = 800;
    uint public supplyCap; // Current total supply cap according to lastStakePriceUSCents and poolCapUSD 
    uint public businessPlannedPeriodDuration = 183 days; // total period planned for business activity 365 days
    uint public businessPlannedPeriodEndTimestamp;
    uint public teamCap; // team Stakes capacity
    uint8 public teamShare = 55; // share for team
    uint public distributedTeamStakes; // distributed Stakes to team    
    uint public fundariaCap; // Fundaria Stakes capacity
    uint8 public fundariaShare = 20; // share for Fundaria
    uint public distributedFundariaStakes; // distributed Stakes to Fundaria
    uint public contractCreatedTimestamp; // when this contract was created
    address public pool = 0x28C19cEb598fdb171048C624DB8b91C56Af29aA2; // initial pool wallet address  
    mapping (address=>bool) public rejectedInvestmentWithdrawals;
    uint public allowedAmountToTransferToPool; // this amount is increased when investor rejects to withdraw his/her investment
    uint public allowedAmountTransferedToPoolTotal; // sum of all allowedAmountToTransferToPool used 
    uint public investmentGuidesRewardsWithdrawn; // total amount of rewards wei withdrawn by Guides  

/********** 
 * Bounty *
 **********/
 
    uint public distributedBountyStakes; // bounty advisors Stakes distributed total    
    uint public bountyCap; // bounty advisors Stakes capacity    
    uint8 public bountyShare = 4; // share for bounty    
    
/*********** 
 * Sale *
 ***********/
    address supplier = 0x0000000000000000000000000000000000000000; // address of Stakes initial supplier (abstract)
    // data to store invested wei value & Stakes for Investor
    struct saleData {
      uint stakes; // how many Stakes where recieved by this Investor total
      uint invested; // how much wei this Investor invested total
      uint bonusStakes; // how many bonus Stakes where recieved by this Investor
      uint guideReward; // Investment Guide reward amount
      address guide; // address of Investment Guide
    }
    mapping (address=>saleData) public saleStat; // invested value + Stakes data for every Investor        
    uint public saleStartTimestamp = 1524852000; // regular Stakes sale start date            
    uint public saleEndTimestamp = 1527444000; 
    uint public distributedSaleStakes; // distributed stakes to all Investors
    uint public totalInvested; //how many invested total
    uint public totalWithdrawn; //how many withdrawn total
    uint public saleCap; // regular sale Stakes capacity   
    uint8 public saleShare = 20; // share for regular sale
    uint public lastStakePriceUSCents; // Stake price in U.S. cents is determined according to current timestamp (the further - the higher price)    
    uint[] public targetPrice;    
    bool public priceIsFrozen = false; // stop increasing the price temporary (in case of low demand. Can be called only after saleEndTimestamp)       
    
/************************************ 
 * Bonus Stakes & Investment Guides *
 ************************************/    
    // data to store Investment Guide reward
    struct guideData {
      bool registered; // is this Investment Guide registered
      uint accumulatedPotentialReward; // how many reward wei are potentially available
      uint rewardToWithdraw; // availabe reward to withdraw now
      uint periodicallyWithdrawnReward; // how much reward wei where withdrawn by this Investment Guide already
    }
    mapping (address=>guideData) public guidesStat; // mapping of Investment Guides datas    
    uint public bonusCap; // max amount of bonus Stakes availabe
    uint public distributedBonusStakes; // how many bonus Stakes are already distributed
    uint public bonusShare = 1; // share of bonus Stakes in supplyCap
    uint8 public guideInvestmentAttractedShareToPay = 10; // reward for the Investment Guide

/*
  WANT TO EARN ON STAKES SALE ?
  BECOME INVESTMENT GUIDE AND RECIEVE 10% OF ATTRACTED INVESTMENT !
  INTRODUCE YOURSELF ON 