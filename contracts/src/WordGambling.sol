// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract WordGambling is ReentrancyGuard, Ownable {
    enum PoolStatus { Active, Settled, Cancelled, Paused, Full }

    struct Pool {
        address creator;
        uint256 creatorDeposit;
        uint256 totalChallengerDeposits;
        uint256 maxChallengers;           // 最大挑战者数量
        uint256 currentChallengerCount;   // 当前挑战者数量
        PoolStatus status;
        uint256 createdAt;
        uint256 settledAt;
        address winner;
        string gameDescription;
        uint256 challengeFeePercentage;   // 挑战费用百分比（10% = 1000）
    }

    struct ChallengerDeposit {
        address challenger;
        uint256 amount;
        uint256 timestamp;
    }

    event PoolCreated(uint256 indexed poolId, address indexed creator, uint256 creatorDeposit, uint256 maxChallengers, uint256 challengeFeePercentage, string gameDescription);
    event ChallengerDeposited(uint256 indexed poolId, address indexed challenger, uint256 amount);
    event PoolSettled(uint256 indexed poolId, address indexed winner, uint256 totalAmount, uint256 feeAmount);
    event PoolCancelled(uint256 indexed poolId);
    event PoolPaused(uint256 indexed poolId);
    event PoolResumed(uint256 indexed poolId);
    event EmergencyWithdraw(address indexed owner, uint256 amount);

    uint256 public poolCounter;
    mapping(uint256 => Pool) public pools;
    mapping(uint256 => ChallengerDeposit[]) public challengerDeposits;
    mapping(uint256 => mapping(address => uint256)) public challengerAmounts;

    uint256 public platformFee = 25; // 0.25%
    uint256 public constant FEE_DENOMINATOR = 10000;
    uint256 public constant CHALLENGE_FEE_PERCENTAGE = 1000; // 10% = 1000
    
    IERC20 public immutable wordFunToken;

    constructor(address _wordFunToken) Ownable(msg.sender) {
        require(_wordFunToken != address(0), "Invalid WordFunToken address");
        wordFunToken = IERC20(_wordFunToken);
    }

    function createPool(
        uint256 maxChallengers,
        string memory gameDescription, 
        uint256 creatorDeposit
    ) external nonReentrant {
        require(creatorDeposit > 0, "Creator deposit must be greater than 0");
        require(maxChallengers > 0, "Max challengers must be greater than 0");
        require(bytes(gameDescription).length > 0, "Game description cannot be empty");
        require(wordFunToken.allowance(msg.sender, address(this)) >= creatorDeposit, "Insufficient WordFunToken allowance");
        require(wordFunToken.balanceOf(msg.sender) >= creatorDeposit, "Insufficient WordFunToken balance");

        // 转移 WordFunToken 到合约
        require(wordFunToken.transferFrom(msg.sender, address(this), creatorDeposit), "WordFunToken transfer failed");

        uint256 poolId = poolCounter++;
        
        pools[poolId] = Pool({
            creator: msg.sender,
            creatorDeposit: creatorDeposit,
            totalChallengerDeposits: 0,
            maxChallengers: maxChallengers,
            status: PoolStatus.Active,
            createdAt: block.timestamp,
            settledAt: 0,
            winner: address(0),
            gameDescription: gameDescription,
            currentChallengerCount: 0,
            challengeFeePercentage: CHALLENGE_FEE_PERCENTAGE
        });

        emit PoolCreated(poolId, msg.sender, creatorDeposit, maxChallengers, CHALLENGE_FEE_PERCENTAGE, gameDescription);
    }

    function depositToPool(uint256 poolId) external nonReentrant {
        Pool storage pool = pools[poolId];
        require(pool.status == PoolStatus.Active, "Pool is not active");
        require(msg.sender != pool.creator, "Creator cannot be challenger");
        require(pool.currentChallengerCount < pool.maxChallengers, "Pool is full");
        require(challengerAmounts[poolId][msg.sender] == 0, "Already participated");

        // 计算当前池子总资金量
        uint256 currentPoolTotal = pool.creatorDeposit + pool.totalChallengerDeposits;
        
        // 计算挑战费用（当前池子总资金量的10%）
        uint256 challengeFee = (currentPoolTotal * pool.challengeFeePercentage) / FEE_DENOMINATOR;
        
        require(wordFunToken.allowance(msg.sender, address(this)) >= challengeFee, "Insufficient WordFunToken allowance");
        require(wordFunToken.balanceOf(msg.sender) >= challengeFee, "Insufficient WordFunToken balance");

        // 转移 WordFunToken 到合约
        require(wordFunToken.transferFrom(msg.sender, address(this), challengeFee), "WordFunToken transfer failed");

        challengerDeposits[poolId].push(ChallengerDeposit({
            challenger: msg.sender,
            amount: challengeFee,
            timestamp: block.timestamp
        }));

        challengerAmounts[poolId][msg.sender] = challengeFee;
        pool.totalChallengerDeposits += challengeFee;
        pool.currentChallengerCount++;

        // 检查是否达到最大挑战者数量
        if (pool.currentChallengerCount >= pool.maxChallengers) {
            pool.status = PoolStatus.Full;
        }

        emit ChallengerDeposited(poolId, msg.sender, challengeFee);
    }

    function settlePool(uint256 poolId, address winner, bool isSuccess) external nonReentrant {
        Pool storage pool = pools[poolId];
        require(pool.status == PoolStatus.Active || pool.status == PoolStatus.Full, "Pool is not active");
        require(msg.sender == pool.creator || msg.sender == owner(), "Only creator or owner can settle");
        require(winner != address(0), "Invalid winner address");

        pool.status = PoolStatus.Settled;
        pool.settledAt = block.timestamp;
        pool.winner = winner;

        uint256 totalAmount = pool.creatorDeposit + pool.totalChallengerDeposits;
        uint256 feeAmount = (totalAmount * platformFee) / FEE_DENOMINATOR;
        uint256 winnerAmount = totalAmount - feeAmount;

        if (isSuccess) {
            // 挑战成功：获胜者获得池子所有资金（扣除平台费用）
            require(wordFunToken.transfer(winner, winnerAmount), "Transfer to winner failed");
        } else {
            // 挑战失败：获胜者获得池子所有资金（扣除平台费用），挑战者资金被罚没
            require(wordFunToken.transfer(winner, winnerAmount), "Transfer to winner failed");
        }

        // 转移平台费用给合约拥有者
        if (feeAmount > 0) {
            require(wordFunToken.transfer(owner(), feeAmount), "Fee transfer failed");
        }

        emit PoolSettled(poolId, winner, totalAmount, feeAmount);
    }

    function cancelPool(uint256 poolId) external nonReentrant {
        Pool storage pool = pools[poolId];
        require(pool.status == PoolStatus.Active, "Pool is not active");
        require(msg.sender == pool.creator, "Only creator can cancel");
        require(pool.totalChallengerDeposits == 0, "Cannot cancel after challenger deposits");

        pool.status = PoolStatus.Cancelled;

        // 退还庄家 WordFunToken
        require(wordFunToken.transfer(pool.creator, pool.creatorDeposit), "Refund failed");

        emit PoolCancelled(poolId);
    }

    function getPool(uint256 poolId) external view returns (Pool memory) {
        return pools[poolId];
    }

    function getChallengerDeposits(uint256 poolId) external view returns (ChallengerDeposit[] memory) {
        return challengerDeposits[poolId];
    }

    function getChallengerAmount(uint256 poolId, address challenger) external view returns (uint256) {
        return challengerAmounts[poolId][challenger];
    }

    function setPlatformFee(uint256 newFee) external onlyOwner {
        require(newFee <= 1000, "Fee too high");
        platformFee = newFee;
    }

    function emergencyWithdraw() external onlyOwner {
        uint256 balance = wordFunToken.balanceOf(address(this));
        require(balance > 0, "No WordFunToken to withdraw");
        
        require(wordFunToken.transfer(owner(), balance), "Transfer failed");
        
        emit EmergencyWithdraw(owner(), balance);
    }

    function getContractBalance() external view returns (uint256) {
        return wordFunToken.balanceOf(address(this));
    }

    function getPoolCount() external view returns (uint256) {
        return poolCounter;
    }

    /**
     * @dev 计算当前池子的挑战费用
     * @param poolId 池子ID
     */
    function getCurrentChallengeFee(uint256 poolId) external view returns (uint256) {
        Pool storage pool = pools[poolId];
        uint256 currentPoolTotal = pool.creatorDeposit + pool.totalChallengerDeposits;
        return (currentPoolTotal * pool.challengeFeePercentage) / FEE_DENOMINATOR;
    }

    /**
     * @dev 检查地址是否有参赛资格
     * @param poolId 池子ID
     * @param challenger 挑战者地址
     */
    function canParticipate(uint256 poolId, address challenger) public view returns (bool) {
        Pool storage pool = pools[poolId];
        
        // 检查池子状态
        if (pool.status != PoolStatus.Active && pool.status != PoolStatus.Full) {
            return false;
        }
        
        // 检查是否已达到最大挑战者数量
        if (pool.currentChallengerCount >= pool.maxChallengers) {
            return false;
        }
        
        // 检查是否已经参与过（每个玩家只能参与一次）
        if (challengerAmounts[poolId][challenger] > 0) {
            return false;
        }
        
        // 检查是否是创建者
        if (challenger == pool.creator) {
            return false;
        }
        
        return true;
    }

    /**
     * @dev 检查地址是否已参与某个池子
     * @param poolId 池子ID
     * @param challenger 挑战者地址
     */
    function hasParticipated(uint256 poolId, address challenger) external view returns (bool) {
        return challengerAmounts[poolId][challenger] > 0;
    }

    /**
     * @dev 获取池子的挑战者列表
     * @param poolId 池子ID
     */
    function getChallengers(uint256 poolId) external view returns (address[] memory) {
        ChallengerDeposit[] memory deposits = challengerDeposits[poolId];
        address[] memory challengers = new address[](pools[poolId].currentChallengerCount);
        
        uint256 uniqueIndex = 0;
        for (uint256 i = 0; i < deposits.length; i++) {
            bool found = false;
            for (uint256 j = 0; j < uniqueIndex; j++) {
                if (challengers[j] == deposits[i].challenger) {
                    found = true;
                    break;
                }
            }
            if (!found) {
                challengers[uniqueIndex] = deposits[i].challenger;
                uniqueIndex++;
            }
        }
        
        return challengers;
    }

    /**
     * @dev 暂停池子（仅庄家或合约拥有者）
     * @param poolId 池子ID
     */
    function pausePool(uint256 poolId) external {
        Pool storage pool = pools[poolId];
        require(pool.status == PoolStatus.Active, "Pool is not active");
        require(msg.sender == pool.creator || msg.sender == owner(), "Only creator or owner can pause");
        
        pool.status = PoolStatus.Paused;
        emit PoolPaused(poolId);
    }

    /**
     * @dev 恢复池子（仅庄家或合约拥有者）
     * @param poolId 池子ID
     */
    function resumePool(uint256 poolId) external {
        Pool storage pool = pools[poolId];
        require(pool.status == PoolStatus.Paused, "Pool is not paused");
        require(msg.sender == pool.creator || msg.sender == owner(), "Only creator or owner can resume");
        
        pool.status = PoolStatus.Active;
        emit PoolResumed(poolId);
    }

    /**
     * @dev 获取池子的详细信息
     * @param poolId 池子ID
     */
    function getPoolDetails(uint256 poolId) external view returns (
        address creator,
        uint256 creatorDeposit,
        uint256 totalChallengerDeposits,
        PoolStatus status,
        uint256 createdAt,
        uint256 settledAt,
        address winner,
        string memory gameDescription,
        uint256 maxChallengers,
        uint256 currentChallengerCount,
        uint256 challengeFeePercentage
    ) {
        Pool storage pool = pools[poolId];
        return (
            pool.creator,
            pool.creatorDeposit,
            pool.totalChallengerDeposits,
            pool.status,
            pool.createdAt,
            pool.settledAt,
            pool.winner,
            pool.gameDescription,
            pool.maxChallengers,
            pool.currentChallengerCount,
            pool.challengeFeePercentage
        );
    }

    /**
     * @dev 获取用户参与的所有池子
     * @param user 用户地址
     */
    function getUserPools(address user) external view returns (uint256[] memory) {
        uint256[] memory tempPools = new uint256[](poolCounter);
        uint256 count = 0;
        
        for (uint256 i = 0; i < poolCounter; i++) {
            if (challengerAmounts[i][user] > 0 || pools[i].creator == user) {
                tempPools[count] = i;
                count++;
            }
        }
        
        uint256[] memory result = new uint256[](count);
        for (uint256 i = 0; i < count; i++) {
            result[i] = tempPools[i];
        }
        
        return result;
    }
} 