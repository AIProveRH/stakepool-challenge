// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * StakePool — a single-asset staking vault.
 *
 * Users stake an ERC20 (`stakeToken`), accrue a second ERC20 (`rewardToken`)
 * proportional to time-weighted stake, and withdraw. The owner funds rewards and
 * tunes the emission rate. A price oracle values the pool's TVL in USD for a
 * deposit cap and an off-chain dashboard. Ownership is handed over in two steps.
 *
 * This contract is an AIProve bug-hunt challenge. It is DELIBERATELY vulnerable.
 * Do not deploy it with real funds.
 */

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address who) external view returns (uint256);
}

interface IPriceOracle {
    // 1e8-scaled USD price of 1 whole stakeToken
    function price() external view returns (uint256);
}

contract StakePool {
    IERC20 public stakeToken;
    IERC20 public rewardToken;
    IPriceOracle public oracle;

    address public owner;
    address public pendingOwner;
    bool private initialized;

    uint256 public rewardRate;          // reward tokens emitted per second across the whole pool
    uint256 public tvlCapUsd;           // max pool TVL in USD (1e8 scaled), 0 = uncapped
    uint256 public totalStaked;
    uint256 public rewardPerTokenStored;
    uint256 public lastUpdate;

    // reward accounting is scaled by ACC to carry fractional per-token amounts
    uint256 private constant ACC = 1e12;

    mapping(address => uint256) public staked;
    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public rewards;

    bool private entered;
    modifier nonReentrant() {
        require(!entered, "reentrant");
        entered = true;
        _;
        entered = false;
    }

    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event Claimed(address indexed user, uint256 amount);
    event OwnershipTransferred(address indexed from, address indexed to);

    function initialize(address _stake, address _reward, address _oracle) external {
        require(!initialized, "init");
        stakeToken = IERC20(_stake);
        rewardToken = IERC20(_reward);
        oracle = IPriceOracle(_oracle);
        owner = msg.sender;
        lastUpdate = block.timestamp;
    }

    // ------------------------------------------------------------- ownership
    function transferOwnership(address next) external {
        require(msg.sender == owner, "not owner");
        pendingOwner = next;
    }

    function acceptOwnership() external {
        address prev = owner;
        owner = pendingOwner;
        emit OwnershipTransferred(prev, owner);
    }

    // ----------------------------------------------------------- reward math
    function rewardPerToken() public view returns (uint256) {
        if (totalStaked == 0) return rewardPerTokenStored;
        uint256 elapsed = block.timestamp - lastUpdate;
        return rewardPerTokenStored + (elapsed * rewardRate * ACC) / totalStaked;
    }

    function earned(address user) public view returns (uint256) {
        uint256 delta = rewardPerToken() - userRewardPerTokenPaid[user];
        return rewards[user] + (staked[user] * delta) / ACC;
    }

    function _updateReward(address user) internal {
        rewardPerTokenStored = rewardPerToken();
        lastUpdate = block.timestamp;
        rewards[user] = earned(user);
        userRewardPerTokenPaid[user] = rewardPerTokenStored;
    }

    function _tvlUsd(uint256 staked_) internal view returns (uint256) {
        // price is 1e8-scaled USD per whole token; stake amounts are 1e18
        return (staked_ * oracle.price()) / 1e18;
    }

    // --------------------------------------------------------------- staking
    function stake(uint256 amount) external nonReentrant {
        require(amount > 0, "zero");
        _updateReward(msg.sender);
        if (tvlCapUsd != 0) {
            require(_tvlUsd(totalStaked + amount) <= tvlCapUsd, "cap");
        }
        stakeToken.transferFrom(msg.sender, address(this), amount);
        staked[msg.sender] += amount;
        totalStaked += amount;
        emit Staked(msg.sender, amount);
    }

    function withdraw(uint256 amount) external {
        require(staked[msg.sender] >= amount, "insufficient");
        _updateReward(msg.sender);
        stakeToken.transfer(msg.sender, amount);
        staked[msg.sender] -= amount;
        totalStaked -= amount;
        emit Withdrawn(msg.sender, amount);
    }

    function claim() external nonReentrant {
        _updateReward(msg.sender);
        uint256 r = rewards[msg.sender];
        rewards[msg.sender] = 0;
        rewardToken.transfer(msg.sender, r);
        emit Claimed(msg.sender, r);
    }

    // ----------------------------------------------------------------- admin
    function setRewardRate(uint256 rate) external {
        require(msg.sender == owner, "not owner");
        rewardRate = rate;
    }

    function setTvlCap(uint256 capUsd) external {
        require(msg.sender == owner, "not owner");
        tvlCapUsd = capUsd;
    }

    function recoverToken(address token, uint256 amount) external {
        require(msg.sender == owner, "not owner");
        IERC20(token).transfer(owner, amount);
    }
}
