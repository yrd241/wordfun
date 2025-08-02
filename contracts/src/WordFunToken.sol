// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title WordFunToken
 * @dev WordFun 游戏代币合约
 * 总量: 1,000,000,000
 * 精度: 18
 * 名称: wordfun
 * 符号: word
 */
contract WordFunToken is ERC20, Ownable {
    uint256 public constant TOTAL_SUPPLY = 1_000_000_000 * 10**18; // 10亿代币
    
    constructor() ERC20("wordfun", "word") Ownable(msg.sender) {
        _mint(msg.sender, TOTAL_SUPPLY);
    }
    
    /**
     * @dev 销毁代币（仅合约拥有者）
     * @param amount 销毁数量
     */
    function burn(uint256 amount) external onlyOwner {
        _burn(msg.sender, amount);
    }
    
    /**
     * @dev 从指定地址销毁代币（仅合约拥有者）
     * @param from 销毁地址
     * @param amount 销毁数量
     */
    function burnFrom(address from, uint256 amount) external onlyOwner {
        _burn(from, amount);
    }
    
    /**
     * @dev 铸造代币（仅合约拥有者）
     * @param to 接收地址
     * @param amount 铸造数量
     */
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }
    

} 