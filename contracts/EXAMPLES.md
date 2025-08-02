# WordGambling 使用示例

本文档提供了 WordGambling 合约的详细使用示例。

## 前置准备

### 1. 获取 WordFunToken 合约地址

```javascript
// 部署时输出的 WordFunToken 地址
const WORDFUN_TOKEN_ADDRESS = "0x..."; // 请替换为实际部署的地址
```

### 2. 部署合约

```bash
export PRIVATE_KEY=your_private_key

forge script script/Deploy.s.sol --rpc-url $RPC_URL --broadcast
```

## 使用示例

### 1. 庄家创建池子

```javascript
// 1. 首先授权合约使用 WordFunToken
const wordFunTokenContract = new ethers.Contract(WORDFUN_TOKEN_ADDRESS, ERC20_ABI, signer);
const creatorDeposit = ethers.utils.parseUnits("1000", 18); // 1000 WordFunToken

await wordFunTokenContract.approve(gamblingContract.address, creatorDeposit);

// 2. 创建池子
const minChallengerDeposit = ethers.utils.parseUnits("100", 18); // 100 WordFunToken
const maxChallengerDeposits = ethers.utils.parseUnits("5000", 18); // 5000 WordFunToken
const maxChallengers = 10; // 最大10个挑战者
const gameDescription = "Word guessing game - Guess the secret word!";

const tx = await gamblingContract.createPool(
  minChallengerDeposit,
  maxChallengerDeposits,
  maxChallengers,
  gameDescription,
  creatorDeposit
);

const receipt = await tx.wait();
console.log("Pool created! Pool ID:", receipt.events[0].args.poolId);
```

### 2. 挑战者参与游戏

```javascript
// 1. 授权合约使用 WordFunToken
const challengerDeposit = ethers.utils.parseUnits("500", 18); // 500 WordFunToken
await wordFunTokenContract.approve(gamblingContract.address, challengerDeposit);

// 2. 充值到池子
const poolId = 0; // 池子ID
const tx = await gamblingContract.depositToPool(poolId, challengerDeposit);
await tx.wait();

console.log("Successfully deposited to pool!");
```

### 3. 查询池子信息

```javascript
// 获取池子详情
const pool = await gamblingContract.getPool(poolId);
console.log("Pool creator:", pool.creator);
console.log("Creator deposit:", ethers.utils.formatUnits(pool.creatorDeposit, 18), "WordFunToken");
console.log("Total challenger deposits:", ethers.utils.formatUnits(pool.totalChallengerDeposits, 18), "WordFunToken");
console.log("Pool status:", pool.status); // 0=Active, 1=Settled, 2=Cancelled, 3=Paused, 4=Full
console.log("Max challengers:", pool.maxChallengers);
console.log("Current challenger count:", pool.currentChallengerCount);

// 获取挑战者充值记录
const deposits = await gamblingContract.getChallengerDeposits(poolId);
console.log("Number of challengers:", deposits.length);

// 获取特定挑战者的充值金额
const challengerAmount = await gamblingContract.getChallengerAmount(poolId, challengerAddress);
console.log("Challenger amount:", ethers.utils.formatUnits(challengerAmount, 18), "WordFunToken");

// 检查参赛资格
const canParticipate = await gamblingContract.canParticipate(poolId, userAddress);
if (canParticipate) {
  console.log("User can participate in this pool");
} else {
  console.log("User cannot participate in this pool");
}

// 检查是否已参与
const hasParticipated = await gamblingContract.hasParticipated(poolId, userAddress);
if (hasParticipated) {
  console.log("User has already participated in this pool");
} else {
  console.log("User has not participated in this pool yet");
}
```

### 4. 结算游戏

```javascript
// 庄家或合约拥有者结算游戏
const winner = "0x..."; // 获胜者地址
const tx = await gamblingContract.settlePool(poolId, winner);
await tx.wait();

console.log("Game settled! Winner:", winner);

// 验证获胜者收到资金
const winnerBalance = await wordFunTokenContract.balanceOf(winner);
console.log("Winner balance:", ethers.utils.formatUnits(winnerBalance, 18), "WordFunToken");
```

### 5. 取消池子

```javascript
// 只有在没有挑战者充值的情况下才能取消
const tx = await gamblingContract.cancelPool(poolId);
await tx.wait();

console.log("Pool cancelled successfully!");
```

## 前端集成示例

### React Hook 示例

```javascript
import { useState, useEffect } from 'react';
import { ethers } from 'ethers';

export function useWordGambling(contractAddress, usdcAddress) {
  const [pools, setPools] = useState([]);
  const [loading, setLoading] = useState(false);

  // 创建池子
  const createPool = async (minDeposit, maxDeposits, description, creatorDeposit) => {
    setLoading(true);
    try {
      const signer = provider.getSigner();
      const wordFunTokenContract = new ethers.Contract(wordFunTokenAddress, ERC20_ABI, signer);
      const gamblingContract = new ethers.Contract(contractAddress, GAMBLING_ABI, signer);

      // 授权
      await wordFunTokenContract.approve(contractAddress, creatorDeposit);
      
      // 创建池子
      const tx = await gamblingContract.createPool(
        minDeposit,
        maxDeposits,
        description,
        creatorDeposit
      );
      
      await tx.wait();
      return tx;
    } catch (error) {
      console.error('Error creating pool:', error);
      throw error;
    } finally {
      setLoading(false);
    }
  };

  // 充值到池子
  const depositToPool = async (poolId, amount) => {
    setLoading(true);
    try {
      const signer = provider.getSigner();
      const wordFunTokenContract = new ethers.Contract(wordFunTokenAddress, ERC20_ABI, signer);
      const gamblingContract = new ethers.Contract(contractAddress, GAMBLING_ABI, signer);

      // 授权
      await wordFunTokenContract.approve(contractAddress, amount);
      
      // 充值
      const tx = await gamblingContract.depositToPool(poolId, amount);
      await tx.wait();
      return tx;
    } catch (error) {
      console.error('Error depositing to pool:', error);
      throw error;
    } finally {
      setLoading(false);
    }
  };

  return {
    pools,
    loading,
    createPool,
    depositToPool
  };
}
```

## 错误处理

### 常见错误及解决方案

1. **"Insufficient WordFunToken allowance"**
   - 解决方案: 调用 `wordFunToken.approve(contractAddress, amount)` 授权

2. **"Insufficient WordFunToken balance"**
   - 解决方案: 确保账户有足够的 WordFunToken 余额

3. **"Pool is not active"**
   - 解决方案: 检查池子状态，只有 Active 状态的池子可以充值

4. **"Creator cannot be challenger"**
   - 解决方案: 庄家不能在自己的池子中充值

5. **"Deposit too small"**
   - 解决方案: 充值金额必须大于等于最小充值金额

6. **"Not eligible to participate"**
   - 解决方案: 检查池子状态、是否已参与、是否达到最大挑战者数量

7. **"Pool is not active"**
   - 解决方案: 池子可能已暂停、已满或已结算，检查池子状态

## Gas 优化建议

1. **批量操作**: 如果需要创建多个池子，考虑批量操作
2. **授权优化**: 一次性授权足够大的金额，避免重复授权
3. **事件监听**: 使用事件监听而不是轮询查询状态

## 测试网络部署

```bash
# 部署到 Polygon Mumbai 测试网
export RPC_URL=https://rpc-mumbai.maticvigil.com

forge script script/Deploy.s.sol --rpc-url $RPC_URL --broadcast --verify
``` 