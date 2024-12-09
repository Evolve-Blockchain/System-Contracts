// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

interface IToken
{
    function totalSupply() external view returns(uint256);
    function balanceOf(address user) external view returns(uint256);
    function deposit() payable external ;
    function transfer(address _to, uint256 amount) external returns(bool);
}
/**
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * By default, the owner account will be the one that deploys the contract. This
 * can later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor() {
        _transferOwnership(_msgSender());
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if the sender is not the owner.
     */
    function _checkOwner() internal view virtual {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(
            newOwner != address(0),
            "Ownable: new owner is the zero address"
        );
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Internal function without access restriction.
     */
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}
contract CoinPool is Ownable   {

    uint256 public rewardFund;
    uint256 public rewardsGiven;
    uint256 public totalClaimedReward;
    uint256 public rewardpertoken;
    uint256 public lastdistributionTime;
    address public WEVO ;
    mapping(address => uint256) public claimedRewards;
    //user -- claimed time
    mapping(address => uint256) public lastClaimedtime;
    mapping(address => uint256) public lastrewardpertoken;
    mapping(address => bool) public blacklisted;

    event claimEV(address indexed _user,uint256 amount, uint256 claimtime);
    receive() external payable {
        rewardFund += msg.value;
        if(WEVO != address(0)){
          distributerewards();
        }
    }
    function getrewardFund() payable external{
        rewardFund += msg.value;
        if(WEVO != address(0)){
            distributerewards();
        }
    }

    function distributerewards() public
    {
        if(rewardFund > 0  && IToken(WEVO).totalSupply()>0)
        {
            rewardsGiven += rewardFund;
            rewardpertoken = (rewardsGiven * 1e9) / IToken(WEVO).totalSupply();
            rewardFund = 0;
            lastdistributionTime = block.timestamp;
        }
    }
    function setWEVO(address _WEVO) external onlyOwner{
      require(_WEVO != address(0), "Invalid address");
      WEVO = _WEVO;
    }
    function rescue() external onlyOwner{
        payable(msg.sender).transfer(address(this).balance);
    }
    function setBlacklisted(address user, bool status) external onlyOwner
    {
        if(!status && blacklisted[user])
        {
            lastClaimedtime[user]=block.timestamp;
            lastrewardpertoken[user] = rewardpertoken ;
        }               
        blacklisted[user] = status;
    }
    function claim() external
    {
        uint256 claimable = _claimable(msg.sender);
        claimedRewards[msg.sender] += claimable;
        totalClaimedReward += claimable;
        lastClaimedtime[msg.sender] = block.timestamp;
        IToken(WEVO).deposit{value:claimable}();
        IToken(WEVO).transfer(msg.sender, claimable);        
        emit claimEV(msg.sender, claimable, block.timestamp);
    }
    function _claimable(address user) internal view returns(uint256)
    {
        require(IToken(WEVO).balanceOf(user) > 0, "no tokens");
        require(!blacklisted[user],"User has been excluded from rewards");
        require((lastdistributionTime > lastClaimedtime[user]) && (rewardpertoken - lastrewardpertoken[user]) > 0, "No amount to claim");
        require(rewardsGiven - totalClaimedReward > 0, "No reward remain") ;        
        return (((rewardpertoken - lastrewardpertoken[user]) * IToken(WEVO).balanceOf(user))/1e9)   - claimedRewards[user];
    }
    function viewRewards(address user) public view returns(uint256)
    {
        if(IToken(WEVO).balanceOf(user)>0 && !blacklisted[user] && 
        ((lastdistributionTime > lastClaimedtime[user]) && 
        (rewardpertoken - lastrewardpertoken[user]) > 0) &&
        (rewardsGiven - totalClaimedReward > 0)
        )
        {
            return (((rewardpertoken - lastrewardpertoken[user]) * IToken(WEVO).balanceOf(user))/1e9)   - claimedRewards[user];
        }   
        return 0;
    }
}
