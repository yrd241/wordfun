# WordGambling - 链上赌博游戏合约

这是一个基于 Foundry 开发的链上赌博游戏合约，支持庄家创建池子、挑战者充值、链下结算等功能。合约使用 WordFunToken 作为交易资产。

## 功能特性

### 核心功能
- **创建池子**: 庄家可以创建赌博池子并存入资金
- **挑战者充值**: 挑战者可以向活跃的池子充值参与游戏
- **链下结算**: 庄家或合约拥有者可以指定获胜者并结算池子
- **取消池子**: 庄家可以在没有挑战者充值前取消池子

### 安全特性
- 重入攻击防护
- 权限控制
- 资金安全转移
- 平台费用机制

## 合约架构

### 主要数据结构

```solidity
struct Pool {
    address creator;           // 庄家地址
    uint256 creatorDeposit;    // 庄家充值金额
    uint256 totalChallengerDeposits; // 挑战者总充值金额
    uint256 minChallengerDeposit;    // 最小挑战者充值金额
    uint256 maxChallengerDeposits;   // 最大挑战者充值金额
    PoolStatus status;         // 池子状态
    uint256 createdAt;         // 创建时间
    uint256 settledAt;         // 结算时间
    address winner;            // 获胜者地址
    string gameDescription;    // 游戏描述
}
```

### 池子状态
- `Active`: 活跃状态，可以充值
- `Settled`: 已结算
- `Cancelled`: 已取消
- `Paused`: 已暂停
- `Full`: 挑战者已满

## 使用方法

### 1. 创建池子
```solidity
function createPool(
    uint256 minChallengerDeposit,
    uint256 maxChallengerDeposits,
    uint256 maxChallengers,
    string memory gameDescription,
    uint256 creatorDeposit
) external
```

**参数说明:**
- `minChallengerDeposit`: 最小挑战者充值金额 (WordFunToken)
- `maxChallengerDeposits`: 最大挑战者充值金额 (WordFunToken)
- `maxChallengers`: 最大挑战者数量
- `gameDescription`: 游戏描述
- `creatorDeposit`: 庄家充值金额 (WordFunToken)

**注意:** 调用前需要先授权合约使用 WordFunToken

### 2. 挑战者充值
```solidity
function depositToPool(uint256 poolId, uint256 amount) external
```

**参数说明:**
- `poolId`: 池子ID
- `amount`: 充值金额 (WordFunToken)

**注意:** 调用前需要先授权合约使用 WordFunToken

### 3. 结算池子
```solidity
function settlePool(uint256 poolId, address winner) external
```

**参数说明:**
- `poolId`: 池子ID
- `winner`: 获胜者地址

### 4. 取消池子
```solidity
function cancelPool(uint256 poolId) external
```

**参数说明:**
- `poolId`: 池子ID

## 费用机制

- 平台费用: 0.25% (可调整)
- 费用从总池子金额中扣除
- 获胜者获得扣除费用后的全部金额
- 所有金额均以 WordFunToken 计算 (18位小数精度)

## 开发环境

### 安装依赖
```bash
forge install OpenZeppelin/openzeppelin-contracts
```

### 编译合约
```bash
forge build
```

### 运行测试
```bash
forge test
```

### 部署合约
```bash
# 设置环境变量
export PRIVATE_KEY=your_private_key

# 部署到本地网络
forge script script/Deploy.s.sol --rpc-url http://localhost:8545 --broadcast

# 部署到测试网
forge script script/Deploy.s.sol --rpc-url $RPC_URL --broadcast --verify
```

**合约配置:**
- 部署时会自动部署 WordFunToken 合约
- WordGambling 合约会使用部署的 WordFunToken 地址
- 测试时使用 WordFunToken 合约

## 测试用例

项目包含完整的测试用例，覆盖以下场景：

- ✅ 创建池子
- ✅ 挑战者充值
- ✅ 结算池子
- ✅ 取消池子
- ✅ 平台费用计算
- ✅ 错误情况处理
- ✅ 权限控制
- ✅ 参赛资格检查
- ✅ 重复参与防护
- ✅ 最大挑战者数量限制

## 安全考虑

1. **重入攻击防护**: 使用 OpenZeppelin 的 ReentrancyGuard
2. **权限控制**: 只有庄家或合约拥有者可以结算池子
3. **资金安全**: 使用 ERC20 的 `transfer` 和 `transferFrom` 进行安全的 WordFunToken 转移
4. **状态管理**: 严格的状态转换控制
5. **授权检查**: 确保用户已授权合约使用 WordFunToken
6. **参赛资格控制**: 每个玩家只能参与一次，有最大挑战者数量限制

## 许可证

MIT License

## 贡献

欢迎提交 Issue 和 Pull Request！
