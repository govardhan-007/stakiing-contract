// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract StakingContract {
    using SafeERC20 for IERC20;

    IERC20 public usdtToken;
    IERC20 public agfToken;

    struct Stake {
        uint256 amount;
        uint256 startTime;
        uint256 endTime;
        uint256 rewardRate;
        bool withdrawn;
    }

    mapping(address => Stake[]) public stakes;

    uint256[] public lockPeriods = [30 days, 60 days, 90 days, 120 days];
    uint256[] public aprs = [8, 12, 14, 18];

    constructor(IERC20 _usdtToken, IERC20 _agfToken) {
        usdtToken = _usdtToken;
        agfToken = _agfToken;
    }

    function stake(uint256 _amount, uint256 _lockPeriodIndex) external {
        require(_lockPeriodIndex < lockPeriods.length, "Invalid lock period index");

        uint256 lockPeriod = lockPeriods[_lockPeriodIndex];
        uint256 apr = aprs[_lockPeriodIndex];
        
        usdtToken.safeTransferFrom(msg.sender, address(this), _amount);

        stakes[msg.sender].push(Stake({
            amount: _amount,
            startTime: block.timestamp,
            endTime: block.timestamp + lockPeriod,
            rewardRate: apr,
            withdrawn: false
        }));
    }

    function calculateReward(uint256 _amount, uint256 _rewardRate, uint256 _duration) internal pure returns (uint256) {
        return (_amount * _rewardRate * _duration) / (365 days * 100);
    }

    function earned(address _user, uint256 _stakeIndex) public view returns (uint256) {
        require(_stakeIndex < stakes[_user].length, "Invalid stake index");

        Stake memory userStake = stakes[_user][_stakeIndex];
        require(!userStake.withdrawn, "Stake already withdrawn");

        uint256 endTime = block.timestamp < userStake.endTime ? block.timestamp : userStake.endTime;
        uint256 stakingDuration = endTime - userStake.startTime;
        
        return calculateReward(userStake.amount, userStake.rewardRate, stakingDuration);
    }

    function withdraw(uint256 _stakeIndex) external {
        require(_stakeIndex < stakes[msg.sender].length, "Invalid stake index");

        Stake storage userStake = stakes[msg.sender][_stakeIndex];
        require(!userStake.withdrawn, "Stake already withdrawn");
        require(block.timestamp >= userStake.endTime, "Staking period not yet ended");

        uint256 reward = earned(msg.sender, _stakeIndex);

        userStake.withdrawn = true;

        usdtToken.safeTransfer(msg.sender, userStake.amount);
        agfToken.safeTransfer(msg.sender, reward);
    }

    function partialWithdraw(uint256 _stakeIndex) external {
        require(_stakeIndex < stakes[msg.sender].length, "Invalid stake index");

        Stake storage userStake = stakes[msg.sender][_stakeIndex];
        require(!userStake.withdrawn, "Stake already withdrawn");
        require(block.timestamp >= userStake.startTime + 30 days, "Minimum staking period not reached");

        uint256 stakingDuration = block.timestamp - userStake.startTime;
        uint256 reward = calculateReward(userStake.amount, aprs[0], stakingDuration); // APR for 30 days

        userStake.withdrawn = true;

        usdtToken.safeTransfer(msg.sender, userStake.amount);
        agfToken.safeTransfer(msg.sender, reward);
    }

    function unstake(uint256 _stakeIndex) external {
        require(_stakeIndex < stakes[msg.sender].length, "Invalid stake index");

        Stake storage userStake = stakes[msg.sender][_stakeIndex];
        require(!userStake.withdrawn, "Stake already withdrawn");

        userStake.withdrawn = true;

        usdtToken.safeTransfer(msg.sender, userStake.amount);
    }

    function getStakes(address _staker) external view returns (Stake[] memory) {
        return stakes[_staker];
    }
}