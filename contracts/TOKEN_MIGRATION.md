# WordFunToken 迁移说明

## 概述

项目已从使用 USDC 作为游戏资产迁移到使用自定义的 WordFunToken 作为游戏资产。

## WordFunToken 合约详情

### 基本信息
- **名称**: wordfun
- **符号**: word
- **精度**: 18 位小数
- **总供应量**: 1,000,000,000 (10亿代币)
- **标准**: ERC20

### 合约功能
- **转账**: 标准 ERC20 转账功能
- **授权**: 标准 ERC20 授权功能
- **铸造**: 仅合约拥有者可以铸造新代币
- **销毁**: 仅合约拥有者可以销毁代币
- **从指定地址销毁**: 仅合约拥有者可以从指定地址销毁代币

## 主要变更

### 1. 合约变更
- `WordGambling.sol`: 将所有 USDC 引用替换为 WordFunToken
- 构造函数现在接受 WordFunToken 地址作为参数
- 所有金额计算从 6 位小数精度改为 18 位小数精度

### 2. 测试变更
- 更新所有测试用例使用 WordFunToken 而不是 MockUSDC
- 金额精度从 `10**6` 改为 `10**18`
- 添加了完整的 WordFunToken 测试套件

### 3. 部署变更
- 部署脚本现在会先部署 WordFunToken，然后部署 WordGambling
- 不再需要硬编码的 USDC 地址

### 4. 文档变更
- 更新 README.md 中的所有 USDC 引用
- 更新 EXAMPLES.md 中的示例代码
- 精度说明从 6 位小数改为 18 位小数

## 部署流程

### 1. 设置环境变量
```bash
export PRIVATE_KEY=your_private_key
export RPC_URL=your_rpc_url
```

### 2. 部署合约
```bash
forge script script/Deploy.s.sol --rpc-url $RPC_URL --broadcast
```

### 3. 记录合约地址
部署完成后会输出：
```
WordFunToken deployed at: 0x...
WordGambling deployed at: 0x...
```

请记录这两个地址用于后续使用。

## 前端集成

### 1. 更新合约地址
```javascript
const WORDFUN_TOKEN_ADDRESS = "0x..."; // 部署时输出的地址
const GAMBLING_CONTRACT_ADDRESS = "0x..."; // 部署时输出的地址
```

### 2. 更新精度
```javascript
// 旧代码 (USDC)
const amount = ethers.utils.parseUnits("1000", 6);

// 新代码 (WordFunToken)
const amount = ethers.utils.parseUnits("1000", 18);
```

### 3. 更新合约实例
```javascript
// 旧代码
const usdcContract = new ethers.Contract(USDC_ADDRESS, USDC_ABI, signer);

// 新代码
const wordFunTokenContract = new ethers.Contract(WORDFUN_TOKEN_ADDRESS, ERC20_ABI, signer);
```

## 测试验证

运行以下命令验证所有功能正常：

```bash
# 运行所有测试
forge test

# 运行特定测试
forge test --match-contract WordFunTokenTest
forge test --match-contract WordGamblingTest
```

## 注意事项

1. **精度差异**: WordFunToken 使用 18 位小数，而 USDC 使用 6 位小数
2. **授权机制**: 仍然需要先授权 WordFunToken 才能进行游戏操作
3. **余额检查**: 确保用户有足够的 WordFunToken 余额
4. **合约拥有者**: WordFunToken 的拥有者可以铸造和销毁代币

## 向后兼容性

此迁移是破坏性变更，不向后兼容。如果需要在现有网络上进行迁移，需要：

1. 部署新的 WordFunToken 合约
2. 部署新的 WordGambling 合约
3. 通知用户更新前端代码
4. 考虑提供代币兑换机制（如果需要）

## 安全考虑

1. **代币控制**: WordFunToken 的拥有者拥有铸造和销毁权限
2. **权限管理**: 确保代币合约的拥有者权限安全
3. **余额验证**: 前端应验证用户余额和授权状态
4. **错误处理**: 更新错误消息以反映新的代币名称 