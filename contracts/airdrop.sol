// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Airdrop is Ownable{

    IERC20 public airdropToken; 
    mapping(address=>bool) public isGov; 
    uint batchSize=500;
    uint256 airdropAmount=0;
    uint processNum=0;
    uint8 public decimals = 18;

    event Airdropped(
        address indexed addr,
        uint256 amount,
        uint256 processIndex,
        uint256 timestamp,
        string symbol
    );
   
    constructor(
        IERC20 _mtkToken
    ) Ownable(msg.sender) { 
        airdropToken=_mtkToken;
    }

    function setGov(address addr)external onlyOwner {
        isGov[addr]=true;
    }

    function removeGov(address addr)external onlyOwner {
        isGov[addr]=false;
    }

    function airdropERC20(address[] memory recipients, uint256[] memory amounts) external   {
        // 第一步：验证两个数组长度是不是相等
        // 判断转账的amount是否等于amounts之和
        // 遍历去转账空投
        // 每一个地址空投需要将address, amount 事件抛出
        processNum=0;
        airdropAmount=0;
        require(recipients.length==amounts.length, "length of address doesn't match with length of amounts");
        uint256 totalAmount=getSumAmount(amounts);
        totalAmount=totalAmount*10**decimals;
        require(airdropToken.balanceOf(msg.sender)>=totalAmount, "balance is not enough");
        require(isGov[msg.sender]|| msg.sender==owner(), "not the gov or owner");

        for(uint i=0;i<recipients.length/batchSize+1;i++ ){
            uint256 startIndex=i*batchSize;
            uint256 endIndex=(i+1)*batchSize-1;
            if(endIndex>recipients.length){
                endIndex=recipients.length-1;
            }
            for(uint j=startIndex;j<=endIndex;j++){
                address addr =recipients[j];
                uint256 amount=amounts[j]*10**decimals;
                require(amount>0, "Invalid amount");
                require(addr!=address(0), "Invalid address");
                require(airdropToken.transferFrom(msg.sender, addr, amount),"transfer failed") ;
                emit Airdropped(addr,amount,processNum++,block.timestamp, "MTK" );
                airdropAmount+=amount;
            }
        }
          // 判断转账的amount是否等于amounts之和
        require(airdropAmount==totalAmount,string.concat("airdrop amount is not correct, airdrop amount is: ",Strings.toString(airdropAmount),", total amount is: ",Strings.toString(totalAmount)));
    }


    function airdropBNB(address[] memory recipients, uint256[] memory amounts) external payable{
        // 第一步：验证两个数组长度是不是相等，验证接收的BNB数量是不是等于amounts数组之和
        // 遍历去转账空投
        // 每一个地址空投需要将address, amount 事件抛出
         processNum=0;
        require(recipients.length==amounts.length, "length of address doesn't match with length of amounts");
        uint256 totalAmount=getSumAmount(amounts);
        totalAmount=totalAmount*10**decimals;
        require(msg.value ==totalAmount, "balance of BNB is not enough");
        require(isGov[msg.sender]|| msg.sender==owner(), "not the gov or owner");

        for(uint i=0;i<(recipients.length/batchSize)+1;i++ ){
            uint256 startIndex=i*batchSize;
            uint256 endIndex=(i+1)*batchSize-1;
            if(endIndex>recipients.length-1){
                endIndex=recipients.length;
            }
            for(uint j=startIndex;j<=endIndex;j++){
                address addr =recipients[j];
                uint256 amount=amounts[j]*10**decimals;
                require(amount>0, "Invalid amount");
                require(addr!=address(0), "Invalid address");
                (bool success, )=addr.call{value:amount}("");
                require(success,"transfer failed");
                emit Airdropped(addr,amount,processNum++,block.timestamp, "BNB");
            }
        }
         
    }


    /**
     * @dev 接收BNB（必须实现，否则合约无法接收BNB）
     */
    receive() external payable {}

    function getSumAmount( uint256[] memory amounts) internal pure returns (uint256){
        uint256 totalAmount=0;
          for(uint256 i=0; i<amounts.length;i++){
            totalAmount+=amounts[i];
        }
        return totalAmount;
    }

   
}