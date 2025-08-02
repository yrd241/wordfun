// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/WordGambling.sol";
import "../src/WordFunToken.sol";

contract WordGamblingTest is Test {
    WordGambling public gambling;
    WordFunToken public wordFunToken;
    
    address public owner = address(1);
    address public creator = address(2);
    address public challenger1 = address(3);
    address public challenger2 = address(4);
    address public winner = address(5);
    
    function setUp() public {
        // 给所有测试地址一些 ETH
        vm.deal(owner, 100 ether);
        vm.deal(creator, 100 ether);
        vm.deal(challenger1, 100 ether);
        vm.deal(challenger2, 100 ether);
        vm.deal(winner, 100 ether);
        
        // 部署 WordFunToken
        wordFunToken = new WordFunToken();
        
        // 给所有测试地址一些 WordFunToken
        wordFunToken.transfer(owner, 100000 * 10**18); // 10万 WordFunToken
        wordFunToken.transfer(creator, 100000 * 10**18); // 10万 WordFunToken
        wordFunToken.transfer(challenger1, 100000 * 10**18); // 10万 WordFunToken
        wordFunToken.transfer(challenger2, 100000 * 10**18); // 10万 WordFunToken
        wordFunToken.transfer(winner, 100000 * 10**18); // 10万 WordFunToken
        
        vm.startPrank(owner);
        gambling = new WordGambling(address(wordFunToken));
        vm.stopPrank();
    }

    function testCreatePool() public {
        vm.startPrank(creator);
        
        uint256 creatorDeposit = 1000 * 10**18; // 1000 WordFunToken
        uint256 maxChallengers = 10;
        string memory description = "Test gambling game";
        
        // 授权合约使用 WordFunToken
        wordFunToken.approve(address(gambling), creatorDeposit);
        
        gambling.createPool(
            maxChallengers,
            description,
            creatorDeposit,
            3600  // 1小时结算时间
        );
        
        vm.stopPrank();
        
        // 验证池子创建
        WordGambling.Pool memory pool = gambling.getPool(0);
        assertEq(pool.creator, creator);
        assertEq(pool.creatorDeposit, creatorDeposit);
        assertEq(pool.maxChallengers, maxChallengers);
        assertEq(uint256(pool.status), uint256(WordGambling.PoolStatus.Active));
        assertEq(pool.gameDescription, description);
        assertEq(pool.challengeFeePercentage, 1000); // 10%
    }

    function testChallengerDeposit() public {
        // 先创建池子
        vm.startPrank(creator);
        wordFunToken.approve(address(gambling), 1000 * 10**18);
        gambling.createPool(10, "Test game", 1000 * 10**18, 3600);
        vm.stopPrank();
        
        // 计算挑战费用（当前池子总资金量的10%）
        uint256 currentPoolTotal = 1000 * 10**18; // 只有创建者存款
        uint256 expectedChallengeFee = (currentPoolTotal * 1000) / 10000; // 10% = 100 WordFunToken
        
        // 挑战者充值
        vm.startPrank(challenger1);
        wordFunToken.approve(address(gambling), expectedChallengeFee);
        gambling.depositToPool(0);
        vm.stopPrank();
        
        // 验证充值
        assertEq(gambling.getChallengerAmount(0, challenger1), expectedChallengeFee);
        WordGambling.Pool memory pool = gambling.getPool(0);
        assertEq(pool.totalChallengerDeposits, expectedChallengeFee);
    }

    function testSettlePoolSuccess() public {
        // 创建池子
        vm.startPrank(creator);
        wordFunToken.approve(address(gambling), 1000 * 10**18);
        gambling.createPool(10, "Test game", 1000 * 10**18, 3600);
        vm.stopPrank();
        
        // 挑战者充值
        uint256 challengeFee = (1000 * 10**18 * 1000) / 10000; // 10% = 100 WordFunToken
        vm.startPrank(challenger1);
        wordFunToken.approve(address(gambling), challengeFee);
        gambling.depositToPool(0);
        vm.stopPrank();
        
        // 结算池子（成功）
        uint256 balanceBefore = wordFunToken.balanceOf(winner);
        vm.startPrank(creator);
        gambling.settlePool(0, winner, true); // 挑战成功
        vm.stopPrank();
        
        // 验证结算
        WordGambling.Pool memory pool = gambling.getPool(0);
        assertEq(uint256(pool.status), uint256(WordGambling.PoolStatus.Settled));
        assertEq(pool.winner, winner);
        
        // 验证获胜者收到资金（扣除平台费用）
        uint256 totalAmount = 1100 * 10**18; // 1000 + 100 WordFunToken
        uint256 feeAmount = (totalAmount * 25) / 10000; // 0.25% fee
        uint256 winnerAmount = totalAmount - feeAmount;
        assertEq(wordFunToken.balanceOf(winner) - balanceBefore, winnerAmount);
    }

    function testSettlePoolFailure() public {
        // 创建池子
        vm.startPrank(creator);
        wordFunToken.approve(address(gambling), 1000 * 10**18);
        gambling.createPool(10, "Test game", 1000 * 10**18, 3600);
        vm.stopPrank();
        
        // 挑战者充值
        uint256 challengeFee = (1000 * 10**18 * 1000) / 10000; // 10% = 100 WordFunToken
        vm.startPrank(challenger1);
        wordFunToken.approve(address(gambling), challengeFee);
        gambling.depositToPool(0);
        vm.stopPrank();
        
        // 快进时间到1小时后（满足结算时间要求）
        vm.warp(block.timestamp + 3600);
        
        // 结算池子（失败）
        uint256 creatorBalanceBefore = wordFunToken.balanceOf(creator);
        vm.startPrank(creator);
        gambling.settlePool(0, winner, false); // 挑战失败
        vm.stopPrank();
        
        // 验证结算
        WordGambling.Pool memory pool = gambling.getPool(0);
        assertEq(uint256(pool.status), uint256(WordGambling.PoolStatus.Settled));
        assertEq(pool.winner, winner);
        
        // 验证创建者收到资金（扣除平台费用）
        uint256 totalAmount = 1100 * 10**18; // 1000 + 100 WordFunToken
        uint256 feeAmount = (totalAmount * 25) / 10000; // 0.25% fee
        uint256 creatorAmount = totalAmount - feeAmount;
        assertEq(wordFunToken.balanceOf(creator) - creatorBalanceBefore, creatorAmount);
    }

    function testGetCurrentChallengeFee() public {
        // 创建池子
        vm.startPrank(creator);
        wordFunToken.approve(address(gambling), 1000 * 10**18);
        gambling.createPool(10, "Test game", 1000 * 10**18, 3600);
        vm.stopPrank();
        
        // 初始挑战费用
        uint256 initialFee = gambling.getCurrentChallengeFee(0);
        assertEq(initialFee, 100 * 10**18); // 1000 * 10% = 100
        
        // 第一个挑战者充值后，挑战费用增加
        vm.startPrank(challenger1);
        wordFunToken.approve(address(gambling), initialFee);
        gambling.depositToPool(0);
        vm.stopPrank();
        
        // 新的挑战费用
        uint256 newFee = gambling.getCurrentChallengeFee(0);
        uint256 expectedNewFee = ((1000 * 10**18 + 100 * 10**18) * 1000) / 10000; // (1000 + 100) * 10% = 110
        assertEq(newFee, expectedNewFee);
    }

    function testSettlePoolFailureTimeLimit() public {
        // 创建池子，设置1小时结算时间
        vm.startPrank(creator);
        wordFunToken.approve(address(gambling), 1000 * 10**18);
        gambling.createPool(10, "Test game", 1000 * 10**18, 3600); // 1小时
        vm.stopPrank();
        
        // 挑战者充值
        uint256 challengeFee = (1000 * 10**18 * 1000) / 10000; // 10% = 100 WordFunToken
        vm.startPrank(challenger1);
        wordFunToken.approve(address(gambling), challengeFee);
        gambling.depositToPool(0);
        vm.stopPrank();
        
        // 尝试在时间未到时结算失败（应该失败）
        vm.startPrank(creator);
        vm.expectRevert("Settlement time not reached");
        gambling.settlePool(0, winner, false); // 挑战失败
        vm.stopPrank();
        
        // 检查是否可以结算失败
        assertFalse(gambling.canSettleFailure(0));
        
        // 快进时间到1小时后
        vm.warp(block.timestamp + 3600);
        
        // 检查是否可以结算失败
        assertTrue(gambling.canSettleFailure(0));
        
        // 现在可以结算失败
        uint256 creatorBalanceBefore = wordFunToken.balanceOf(creator);
        vm.startPrank(creator);
        gambling.settlePool(0, winner, false); // 挑战失败
        vm.stopPrank();
        
        // 验证创建者收到资金（扣除平台费用）
        uint256 totalAmount = 1100 * 10**18; // 1000 + 100 WordFunToken
        uint256 feeAmount = (totalAmount * 25) / 10000; // 0.25% fee
        uint256 creatorAmount = totalAmount - feeAmount;
        assertEq(wordFunToken.balanceOf(creator) - creatorBalanceBefore, creatorAmount);
    }

    function testGetRemainingSettlementTime() public {
        // 创建池子，设置1小时结算时间
        vm.startPrank(creator);
        wordFunToken.approve(address(gambling), 1000 * 10**18);
        gambling.createPool(10, "Test game", 1000 * 10**18, 3600); // 1小时
        vm.stopPrank();
        
        // 检查剩余时间
        uint256 remainingTime = gambling.getRemainingSettlementTime(0);
        assertEq(remainingTime, 3600); // 应该还有1小时
        
        // 快进30分钟
        vm.warp(block.timestamp + 1800);
        remainingTime = gambling.getRemainingSettlementTime(0);
        assertEq(remainingTime, 1800); // 应该还有30分钟
        
        // 快进到1小时后
        vm.warp(block.timestamp + 1800);
        remainingTime = gambling.getRemainingSettlementTime(0);
        assertEq(remainingTime, 0); // 应该可以结算了
    }
} 