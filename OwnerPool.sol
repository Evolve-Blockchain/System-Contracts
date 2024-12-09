// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

interface IToken
{
    function totalSupply() external view returns(uint256);
    function balanceOf(address user) external view returns(uint256);
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
contract OwnerPool is Ownable   {

    uint256 public rewardFund;
    mapping(address => uint256) public rewardOf;
    mapping(address => uint256) public totalClaimedRewardOf;
    mapping(address => uint256) public rewardpertoken;
    mapping(address => uint256) public lastdistributionTime;
    mapping(address => mapping(address => uint256)) public claimedRewards;
    //token -- user -- claimed time
    mapping(address => mapping(address => uint256)) public lastClaimedtime;
    mapping(address => mapping(address => uint256)) public lastrewardpertoken;

    event claimEV(address indexed _user, address indexed _token, uint256 amount, uint256 claimtime);
    receive() external payable {
        rewardFund += msg.value;
        distributerewards();
    }   
    address[] public whitelisted; //for tokens
    mapping(address => bool) public blacklisted; // for users
    function addwhitelisted(address _adr) external onlyOwner{
        whitelisted.push(_adr);
    }
    function removeByIndex(uint index) public onlyOwner {
        if (index >= whitelisted.length) return;
        whitelisted[index] = whitelisted[whitelisted.length - 1];
        whitelisted.pop();
    }
    function distributerewards() public
    {
        if(rewardFund > 0 && whitelisted.length > 0)
        {
            uint256 tokenShare = rewardFund / whitelisted.length;
            for(uint i = 0; i<whitelisted.length;i++)
            {
                if(IToken(whitelisted[i]).totalSupply() > 0){
                    rewardOf[whitelisted[i]] += tokenShare;
                    rewardpertoken[whitelisted[i]] = (rewardOf[whitelisted[i]] * 1e9) / IToken(whitelisted[i]).totalSupply();
                    rewardFund -= tokenShare;
                    lastdistributionTime[whitelisted[i]] = block.timestamp;
                }
            }
        }
    }
    function rescue() external onlyOwner{
        payable(msg.sender).transfer(address(this).balance);
    }
    function setBlacklisted(address user, bool status) external onlyOwner
    {
        if(!status && blacklisted[user])
        {
             for(uint i = 0; i<whitelisted.length;i++)
            {
                if(IToken(whitelisted[i]).totalSupply() > 0){
                    lastClaimedtime[whitelisted[i]][user]=block.timestamp;
                    lastrewardpertoken[whitelisted[i]][user]= rewardpertoken[whitelisted[i]];             
                }
            }
        }
        blacklisted[user] = status;
    }
    function claim(address _tokenAddress) external
    {        
        uint256 claimable = _claimable(_tokenAddress, msg.sender);//((rewardpertoken[_tokenAddress] * IToken(_tokenAddress).balanceOf(msg.sender))/1e18)   - claimedRewards[_tokenAddress][msg.sender];
        claimedRewards[_tokenAddress][msg.sender] += claimable;        
        totalClaimedRewardOf[_tokenAddress] += claimable;
        lastClaimedtime[_tokenAddress][msg.sender] = block.timestamp;
        payable(msg.sender).transfer(claimable);
        emit claimEV(msg.sender, _tokenAddress, claimable, block.timestamp);
    }
    function _claimable(address _tokenAddress, address user) internal view returns(uint256)
    {
        require(IToken(_tokenAddress).balanceOf(user) > 0, "no tokens");
        require(!blacklisted[user],"User has been excluded from rewards");
        require((lastdistributionTime[_tokenAddress] > lastClaimedtime[_tokenAddress][user]) && (rewardpertoken[_tokenAddress] - lastrewardpertoken[_tokenAddress][user] > 0), "No amount to claim");        
        require(rewardOf[_tokenAddress] - totalClaimedRewardOf[_tokenAddress] > 0, "No reward remain") ;        
        return (((rewardpertoken[_tokenAddress]-lastrewardpertoken[_tokenAddress][user]) * IToken(_tokenAddress).balanceOf(user))/1e9)   - claimedRewards[_tokenAddress][user];
    }
    function viewRewards(address _tokenAddress, address user) public view returns(uint256)
    {
        if(IToken(_tokenAddress).balanceOf(user) > 0 && !blacklisted[user] && 
        (lastdistributionTime[_tokenAddress] > lastClaimedtime[_tokenAddress][user]) && 
        ((rewardpertoken[_tokenAddress] - lastrewardpertoken[_tokenAddress][user]) > 0) &&
        (rewardOf[_tokenAddress] - totalClaimedRewardOf[_tokenAddress] > 0))
        {
            return (((rewardpertoken[_tokenAddress]-lastrewardpertoken[_tokenAddress][user]) * IToken(_tokenAddress).balanceOf(user))/1e9)   - claimedRewards[_tokenAddress][user];
        }
        return 0;
    }
}
