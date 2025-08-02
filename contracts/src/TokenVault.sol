// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title TokenVault
 * @dev 支持 native token 和 ERC20 token 的存款和转账合约
 */
contract TokenVault is ReentrancyGuard, Ownable {
    // 事件定义
    event NativeDeposited(address indexed depositor, uint256 amount);
    event ERC20Deposited(address indexed depositor, address indexed token, uint256 amount);
    event NativeTransferred(address indexed from, address indexed to, uint256 amount);
    event ERC20Transferred(address indexed from, address indexed to, address indexed token, uint256 amount);
    event EmergencyWithdraw(address indexed owner, uint256 nativeAmount);

    // 用户余额映射
    mapping(address => uint256) public nativeBalances;
    mapping(address => mapping(address => uint256)) public erc20Balances; // user => token => balance

    // 构造函数
    constructor() Ownable(msg.sender) {}

    /**
     * @dev 存入 native token (ETH/BNB等)
     */
    function depositNative() external payable nonReentrant {
        require(msg.value > 0, "Amount must be greater than 0");
        
        nativeBalances[msg.sender] += msg.value;
        
        emit NativeDeposited(msg.sender, msg.value);
    }

    /**
     * @dev 存入 ERC20 token
     * @param token ERC20 token 地址
     * @param amount 存入数量
     */
    function depositERC20(address token, uint256 amount) external nonReentrant {
        require(token != address(0), "Invalid token address");
        require(amount > 0, "Amount must be greater than 0");
        
        // 检查用户授权额度
        require(
            IERC20(token).allowance(msg.sender, address(this)) >= amount,
            "Insufficient allowance"
        );
        
        // 转移 token 到合约
        require(
            IERC20(token).transferFrom(msg.sender, address(this), amount),
            "Transfer failed"
        );
        
        erc20Balances[msg.sender][token] += amount;
        
        emit ERC20Deposited(msg.sender, token, amount);
    }

    /**
     * @dev 转账 native token
     * @param to 接收地址
     * @param amount 转账数量
     */
    function transferNative(address to, uint256 amount) external nonReentrant {
        require(to != address(0), "Invalid recipient address");
        require(amount > 0, "Amount must be greater than 0");
        require(nativeBalances[msg.sender] >= amount, "Insufficient balance");
        
        nativeBalances[msg.sender] -= amount;
        nativeBalances[to] += amount;
        
        emit NativeTransferred(msg.sender, to, amount);
    }

    /**
     * @dev 转账 ERC20 token
     * @param token ERC20 token 地址
     * @param to 接收地址
     * @param amount 转账数量
     */
    function transferERC20(address token, address to, uint256 amount) external nonReentrant {
        require(token != address(0), "Invalid token address");
        require(to != address(0), "Invalid recipient address");
        require(amount > 0, "Amount must be greater than 0");
        require(erc20Balances[msg.sender][token] >= amount, "Insufficient balance");
        
        erc20Balances[msg.sender][token] -= amount;
        erc20Balances[to][token] += amount;
        
        emit ERC20Transferred(msg.sender, to, token, amount);
    }

    /**
     * @dev 提取 native token 到外部地址
     * @param to 接收地址
     * @param amount 提取数量
     */
    function withdrawNative(address to, uint256 amount) external nonReentrant {
        require(to != address(0), "Invalid recipient address");
        require(amount > 0, "Amount must be greater than 0");
        require(nativeBalances[msg.sender] >= amount, "Insufficient balance");
        
        nativeBalances[msg.sender] -= amount;
        
        (bool success, ) = to.call{value: amount}("");
        require(success, "Transfer failed");
        
        emit NativeTransferred(msg.sender, to, amount);
    }

    /**
     * @dev 提取 ERC20 token 到外部地址
     * @param token ERC20 token 地址
     * @param to 接收地址
     * @param amount 提取数量
     */
    function withdrawERC20(address token, address to, uint256 amount) external nonReentrant {
        require(token != address(0), "Invalid token address");
        require(to != address(0), "Invalid recipient address");
        require(amount > 0, "Amount must be greater than 0");
        require(erc20Balances[msg.sender][token] >= amount, "Insufficient balance");
        
        erc20Balances[msg.sender][token] -= amount;
        
        require(
            IERC20(token).transfer(to, amount),
            "Transfer failed"
        );
        
        emit ERC20Transferred(msg.sender, to, token, amount);
    }

    /**
     * @dev 查询用户 native token 余额
     * @param user 用户地址
     */
    function getNativeBalance(address user) external view returns (uint256) {
        return nativeBalances[user];
    }

    /**
     * @dev 查询用户 ERC20 token 余额
     * @param user 用户地址
     * @param token ERC20 token 地址
     */
    function getERC20Balance(address user, address token) external view returns (uint256) {
        return erc20Balances[user][token];
    }

    /**
     * @dev 紧急提取合约中的 native token (仅合约拥有者)
     */
    function emergencyWithdrawNative() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No native tokens to withdraw");
        
        (bool success, ) = owner().call{value: balance}("");
        require(success, "Transfer failed");
        
        emit EmergencyWithdraw(owner(), balance);
    }

    /**
     * @dev 紧急提取合约中的 ERC20 token (仅合约拥有者)
     * @param token ERC20 token 地址
     */
    function emergencyWithdrawERC20(address token) external onlyOwner {
        require(token != address(0), "Invalid token address");
        
        uint256 balance = IERC20(token).balanceOf(address(this));
        require(balance > 0, "No tokens to withdraw");
        
        require(
            IERC20(token).transfer(owner(), balance),
            "Transfer failed"
        );
        
        emit ERC20Transferred(address(this), owner(), token, balance);
    }

    /**
     * @dev 接收 native token 的回退函数
     */
    receive() external payable {
        // 直接存入到发送者账户
        nativeBalances[msg.sender] += msg.value;
        emit NativeDeposited(msg.sender, msg.value);
    }
} 