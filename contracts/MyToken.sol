// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MyToken is ERC20, Ownable {

    struct Stake {
        uint256 amount;          // 质押数量
        uint256 startTime;       // 质押开始时间
        uint256 endTime;         // 质押结束时间
        uint256 rewardRate;      // 收益率（根据期限计算）
        bool isActive;           // 订单是否有效
    }

    struct timeMapping {
        uint256 periodDays;
        uint256 time;
    }

    enum StakingPeriod { 
        ThirtyDays,
        NinetyDays, 
        HundredEightyDays, 
        OneYear
    }

    mapping(StakingPeriod => uint256) public apy; // 年化收益率（百分比，如20表示20%）
    mapping(address => mapping(uint256=>Stake)) public userStakes; // 用户的所有质押订单
    mapping(address => uint256) public nextStakeId; // 自增计数器

    event Staked(
        address indexed user,
        uint256 amount,
        StakingPeriod period,
        uint256 timestamp,
        uint256 stakeIndex
    );

    event Withdrawn(
        address indexed user,
        uint256 totalAmount,
        uint256 stakeIndex
    );

    constructor(
        string memory name,
        string memory symbol,
        uint256 initialSupply
    ) ERC20(name, symbol) Ownable(msg.sender)  { 
        _mint(msg.sender, initialSupply * 10 ** decimals());
        apy[StakingPeriod.ThirtyDays] = 10;   // 10% 年化
        apy[StakingPeriod.NinetyDays] = 15;   // 15% 年化
        apy[StakingPeriod.HundredEightyDays] = 20;      // 20% 年化
        apy[StakingPeriod.OneYear] = 25;      // 20% 年化
    }

    // 可选：添加增发功能（仅所有者可调用）
    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }

    function stake(uint256 amount, StakingPeriod period) external {
        uint256 amountWei=amount*10**18;
        require(amount>0, "Amount should be positive");
        require(balanceOf(msg.sender)>=amountWei, "Insufficient balance");

        timeMapping memory durMapping = _getDuration(period);
        uint256 dur=durMapping.time;
        uint256 periodDays=durMapping.periodDays;
        uint256 startT=block.timestamp;
        uint256 endT= startT + dur;
        uint256 index =nextStakeId[msg.sender]++;

        emit Staked(msg.sender, amount, period, endT,index);

        userStakes[msg.sender][index]=Stake({
            amount:amount,
            startTime:startT,
            endTime:endT,         // 质押结束时间
            rewardRate:apy[period]*periodDays*10**18/360,     // 收益率（根据期限计算）
            isActive:true           // 订单是否有效
        });
    }

    // 内部函数：根据期限返回秒数
    function _getDuration(StakingPeriod period) internal pure returns (timeMapping memory) {

        if(period==StakingPeriod.ThirtyDays){
            return timeMapping({
                periodDays:30,
                time:1 minutes
            });
        }else if(period==StakingPeriod.NinetyDays){
            return timeMapping({
                periodDays:90,
                time:3 minutes
            });
        }else if(period==StakingPeriod.HundredEightyDays){
            return timeMapping({
                periodDays:180,
                time:5 minutes
            });
        }else if(period==StakingPeriod.OneYear){
            return timeMapping({
                periodDays:360,
                time:10 minutes
            });
        }else{
            return timeMapping({
                periodDays:360,
                time:1 hours
            });
        }

    }

    function withdraw(uint256 stakeIndex) external {
        Stake storage s = userStakes[msg.sender][stakeIndex];
        require(s.isActive, "Stake is not active or already withdrawn");
        require(block.timestamp >= s.endTime, "Stake period is not ended");
        uint256 reward=s.amount*s.rewardRate/100/10** 18;
        uint256 totalAmount=s.amount+reward;
        s.isActive=false;

        emit Withdrawn(msg.sender,totalAmount,stakeIndex);
    }
}