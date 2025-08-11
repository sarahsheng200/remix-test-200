// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract MtkContracts  {

    struct Stake {
        uint256 amount;          // 质押数量
        uint256 startTime;       // 质押开始时间
        uint256 endTime;         // 质押结束时间
        uint256 rewardRate;      // 收益率（根据期限计算）
        bool isActive;           // 订单是否有效
        uint256 stakeIndex;
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
    
    IERC20 public stakingToken; 

    mapping(StakingPeriod => uint256) public apy; // 年化收益率（百分比，如20表示20%）
    mapping(address => mapping(uint256=>Stake)) public userStakes; // 用户的所有质押订单
    mapping(uint256=>address) public stakeOwnerMapping;
    mapping(address => uint256[]) public userStakeIndexes;

    uint256 private nonce;// 自增计数器

    event Staked(
        address indexed user,
        uint256 amount,
        StakingPeriod period,      
        uint256 stakeIndex,
         uint256 timestamp
    );

    event Withdrawn(
        address indexed user,
        uint256 stakeIndex,    
        uint256 standAmount,
        uint256 reward,
        uint256 totalAmount     
    );

    constructor(
        IERC20 _mtkToken
    )  { 
        stakingToken=_mtkToken;

        apy[StakingPeriod.ThirtyDays] = 10;   // 10% 年化
        apy[StakingPeriod.NinetyDays] = 15;   // 15% 年化
        apy[StakingPeriod.HundredEightyDays] = 20;      // 20% 年化
        apy[StakingPeriod.OneYear] = 25;      // 20% 年化
    }

    function stake(uint256 amount, StakingPeriod period) external {
        require(amount>0, "Amount should be positive");
        require(stakingToken.transferFrom(msg.sender, address(this), amount),"Staking: Transfer failed");
       
        timeMapping memory durMapping = _getDuration(period);
        uint256 dur=durMapping.time;
        uint256 periodDays=durMapping.periodDays;
        uint256 startT=block.timestamp;
        uint256 endT= startT + dur;
        uint256 index =_generateStakeId();
        uint256 rate=apy[period]*periodDays*10**18/360;

        emit Staked(msg.sender, amount, period,index, endT);

        userStakes[msg.sender][index]=Stake({
            amount:amount,
            startTime:startT,
            endTime:endT,         // 质押结束时间
            rewardRate:rate,     // 收益率（根据期限计算）
            isActive:true,           // 订单是否有效
            stakeIndex:index
        });
        stakeOwnerMapping[index]=msg.sender;
        userStakeIndexes[msg.sender].push(index);
        
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
        require(stakeOwnerMapping[stakeIndex]==msg.sender, string.concat("You are not the owner of this stake, stakeIndex is",Strings.toString(stakeIndex)));

        Stake storage s = userStakes[msg.sender][stakeIndex];
       
        require(s.isActive, "Stake is not active or already withdrawn");
        require(block.timestamp >= s.endTime, "Stake period is not ended");
        
        uint256 reward=s.amount*s.rewardRate/100/10**18;
        uint256 totalAmount=s.amount+reward;

        require(stakingToken.transfer( msg.sender, totalAmount),"Withdrawning: Transfer failed");
 
        s.isActive=false;
        emit Withdrawn(msg.sender,stakeIndex,s.amount,reward,totalAmount);
    }

    // 生成唯一的质押ID
    function _generateStakeId() internal returns (uint256) {
        return uint256(keccak256(abi.encodePacked(block.timestamp, msg.sender, nonce++)));
    }
    
    // 获取用户所有活跃的质押
    function getUserActiveStakes(address user) external view returns (Stake[] memory) {       
        
        uint256 activeCount;

        for(uint256 i=0;i<userStakeIndexes[user].length;i++){
            uint256 index=userStakeIndexes[user][i];
            if(userStakes[user][index].isActive){
                activeCount++;
            }
        }

        Stake[] memory activeStakes = new Stake[](activeCount);
        uint256 activeIndex=0;

        for (uint256 i = 0; i < userStakeIndexes[user].length; i++) {
            uint256 index=userStakeIndexes[user][i];
            Stake storage s = userStakes[user][index];
            if (s.isActive) {
                activeStakes[activeIndex]=s;
                activeIndex++;
            }
        }
        
        return activeStakes;
    }
    
}