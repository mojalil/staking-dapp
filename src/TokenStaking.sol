// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.20;

// IMPORTING CONTRACT
import "./Ownable.sol";
import "./ReentrancyGuard.sol";
import "./IERC20.sol";
import "./Initializable.sol";

contract TokenStaking is Ownable, ReentrancyGuard, Initializable {
    struct User {
        uint256 stakeAmount;
        uint256 rewardAmount;
        uint256 lastStakeTime;
        uint256 lastRewardCalcualtionTime;
        uint256 rewardsClaimedSoFar;
    }

    uint256 _minimumStakingAmount;
    uint256 _maxStakeTokenLimit;
    uint256 _stakeEndDate;
    uint256 _stakeStartDate;
    uint256 _totalStakedTokens;
    uint256 _totalUsers;
    uint256 _stakeDays;
    uint256 _earlyUnstakeFeePercentage;
    bool _isStakingPaused;

    address private _tokenAddress;

    // APY
    uint256 _apyRate;

    uint256 public constant PERCENTAGE_DENOMINATOR = 10000;
    uint256 public constant APY_RATE_CHANGE_THRESHOLD = 100;

    // User address => User
    mapping(address => User) private _users;

    // EVENTS
    event Stake(address indexed user, uint256 amount);
    event Unstake(address indexed user, uint256 amount);
    event ClaimReward(address indexed user, uint256 amount);
    event EarlyUnstakeFee(address indexed user, uint256 amount);

    // MODIFIERS
    modifier whenTreasuryHasBalance(uint256 amount) {
        require(
            IERC20(_tokenAddress).balanceOf(address(this)) >= amount,
            "TokenStaking: Insufficient balance in treasury"
        );
        _;
    }

    function initialize(
        address owner_,
        address tokenAddress_,
        uint256 apyRate_,
        uint256 minimumStakingAmount_,
        uint256 maxStakeTokenLimit_,
        uint256 stakeStartDate_,
        uint256 stakeEndDate_,
        uint256 stakeDays_,
        uint256 earlyUnstakeFeePercentage_
    ) public virtual initializer {
        __TokenStaking_init_unchained(
            owner_,
            tokenAddress_,
            apyRate_,
            minimumStakingAmount_,
            maxStakeTokenLimit_,
            stakeStartDate_,
            stakeEndDate_,
            stakeDays_,
            earlyUnstakeFeePercentage_
        );
    }

    function __TokenStaking_init_unchained(
        address owner_,
        address tokenAddress_,
        uint256 apyRate_,
        uint256 minimumStakingAmount_,
        uint256 maxStakeTokenLimit_,
        uint256 stakeStartDate_,
        uint256 stakeEndDate_,
        uint256 stakeDays_,
        uint256 earlyUnstakeFeePercentage_
    ) internal onlyInitializing {
        require(
            _apyRate <= 10000,
            "TokenStaking: apyRate should be less than or equal to 10000"
        );
        require(
            stakeDays_ > 0,
            "TokenStaking: stakeDays should be greater than 0"
        );
        require(
            tokenAddress_ != address(0),
            "TokenStaking: Invalid token address"
        );
        require(
            stakeStartDate_ < stakeEndDate_,
            "TokenStaking: Invalid stake start and end date"
        );

        _transferOwnership(owner_);
        _tokenAddress = tokenAddress_;
        _apyRate = apyRate_;
        _minimumStakingAmount = minimumStakingAmount_;
        _maxStakeTokenLimit = maxStakeTokenLimit_;
        _stakeStartDate = stakeStartDate_;
        _stakeEndDate = stakeEndDate_;
        _stakeDays = stakeDays_ * 1 days;
        _earlyUnstakeFeePercentage = earlyUnstakeFeePercentage_;
    }

    // View Methods Start

    /**
     * @notice This function is used to get the maximum staking token limit for program
     */
    function getMaxStakingTokenLimit() external view returns (uint256) {
        return _maxStakeTokenLimit;
    }

    /// @notice This function is used to get the start date for program
    function getStakeStartDate() external view returns (uint256) {
        return _stakeStartDate;
    }

    /// @notice This function is used to get the end date for program
    function getStakeEndDate() external view returns (uint256) {
        return _stakeEndDate;
    }

    /// @notice This function is used to get the total no of tokens that are staked
    function getTotalStakedTokens() external view returns (uint256) {
        return _totalStakedTokens;
    }

    /// @notice This function is used to get the total no of users
    function getTotalUsers() external view returns (uint256) {
        return _totalUsers;
    }

    /// @notice This function is used to get stake days
    function getStakeDays() external view returns (uint256) {
        return _stakeDays;
    }

    /// @notice This function is used to get early unstake fee percentage
    function getEarlyUnstakeFeePercentage() external view returns (uint256) {
        return _earlyUnstakeFeePercentage;
    }

    /// @notice This function is used to get staking status
    function getStakingStatus() external view returns (bool) {
        return _isStakingPaused;
    }

    /// @notice This function is used to get the current APY Rate
    /// @return Current APY Rate
    function getAPY() external view returns (uint256) {
        return _apyRate;
    }

    /// @notice This function is used to get msg.sender's estimated reward amount
    /// @return msg.sender's estimated reward amount
    function getUserEstimatedRewards() external view returns (uint256) {
      (uint256 amount, ) = _getUserEstimatedRewards(msg.sender);
      return _users[msg.sender].rewardAmount + amount;
    }

    /// @notice This function is used to get withdrawable amount from contract
    function getWithdrawableAmount() external view returns (uint256) {
        return
            IERC20(_tokenAddress).balanceOf(address(this)) - _totalStakedTokens;
    }

    /// @notice This function is used to get User's details
    /// @param userAddress User's address to get details of
    /// @return User Struct
    function getUser(address userAddress) external view returns (User memory) {
        return _users[userAddress];
    }

    /// @notice This function is used to check if a user is a stakeholder
    /// @param _user Address of the user to check
    /// @return True if user is a stakeholder, false otherwise
    function isStakeHolder(address _user) external view returns (bool) {
        return _users[_user].stakeAmount != 0;
    }

    /* View Methods End */ //

    /* Owner Methods Start */
    /// @notice This function is used to update minimum staking amount
    function updateMinimumStakingAmount(uint256 newAmount) external onlyOwner {
        _minimumStakingAmount = newAmount;
    }

    /// @notice This function is used to update maximum staking amount
    function updateMaximumStakingAmount(uint256 newAmount) external onlyOwner {
        _maxStakeTokenLimit = newAmount;
    }

    /// @notice This function is used to update staking end date
    function updateStakingEndDate(uint256 newDate) external onlyOwner {
        _stakeEndDate = newDate;
    }

    /// @notice This function is used to update early unstake fee percentage
    function updateEarlyUnstakeFeePercentage(
        uint256 newPercentage
    ) external onlyOwner {
        _earlyUnstakeFeePercentage = newPercentage;
    }
}
