// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MyToken is ERC20, Ownable {
    constructor(
        string memory name,
        string memory symbol,
        uint256 initialSupply
    ) ERC20(name, symbol) Ownable(msg.sender)  { // 关键修改：将name和symbol传递给ERC20构造函数
        _mint(msg.sender, initialSupply * 10 ** decimals());
    }

    // 可选：添加增发功能（仅所有者可调用）
    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }
}