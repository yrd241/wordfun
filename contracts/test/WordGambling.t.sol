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
        uint256 minChallengerDeposit = 100 * 10**18; // 100 WordFunToken
        uint256 maxChallengerDeposits = 5000 * 10**18; // 5000 WordFunToken
        uint256 maxChallengers = 10;
        string memory description = "Test gambling game";
        
        // 授权合约使用 WordFunToken
        wordFunToken.approve(address(gambling), creatorDeposit);
        
        gambling.createPool(
            minChallengerDeposit,
            maxChallengerDeposits,
            maxChallengers,
            description,
            creatorDeposit
        );
        
        vm.stopPrank();
        
        // 验证池子创建
        WordGambling.Pool memory pool = gambling.getPool(0);
        assertEq(pool.creator, creator);
        assertEq(pool.creatorDeposit, creatorDeposit);
        assertEq(pool.minChallengerDeposit, minChallengerDeposit);
        assertEq(pool.maxChallengerDeposits, maxChallengerDeposits);
        assertEq(pool.maxChallengers, maxChallengers);
        assertEq(uint256(pool.status), uint256(WordGambling.PoolStatus.Active));
        assertEq(pool.gameDescription, description);
    }

    function testChallengerDeposit() public {
        // 先创建池子
        vm.startPrank(creator);
        wordFunToken.approve(address(gambling), 1000 * 10**18);
        gambling.createPool(100 * 10**18, 5000 * 10**18, 10, "Test game", 1000 * 10**18);
        vm.stopPrank();
        
        // 挑战者充值
        vm.startPrank(challenger1);
        uint256 depositAmount = 500 * 10**18; // 500 WordFunToken
        wordFunToken.approve(address(gambling), depositAmount);
        gambling.depositToPool(0, depositAmount);
        vm.stopPrank();
        
        // 验证充值
        assertEq(gambling.getChallengerAmount(0, challenger1), depositAmount);
        WordGambling.Pool memory pool = gambling.getPool(0);
        assertEq(pool.totalChallengerDeposits, depositAmount);
    }

    function testSettlePool() public {
        // 创建池子
        vm.startPrank(creator);
        wordFunToken.approve(address(gambling), 1000 * 10**18);
        gambling.createPool(100 * 10**18, 5000 * 10**18, 10, "Test game", 1000 * 10**18);
        vm.stopPrank();
        
        // 挑战者充值
        vm.startPrank(challenger1);
        wordFunToken.approve(address(gambling), 500 * 10**18);
        gambling.depositToPool(0, 500 * 10**18);
        vm.stopPrank();
        
        vm.startPrank(challenger2);
        wordFunToken.approve(address(gambling), 300 * 10**18);
        gambling.depositToPool(0, 300 * 10**18);
        vm.stopPrank();
        
        // 结算池子
        uint256 balanceBefore = wordFunToken.balanceOf(winner);
        vm.startPrank(creator);
        gambling.settlePool(0, winner);
        vm.stopPrank();
        
        // 验证结算
        WordGambling.Pool memory pool = gambling.getPool(0);
        assertEq(uint256(pool.status), uint256(WordGambling.PoolStatus.Settled));
        assertEq(pool.winner, winner);
        
        // 验证获胜者收到资金（扣除平台费用）
        uint256 expectedAmount = 1800 * 10**18; // 1000 + 500 + 300 WordFunToken
        uint256 feeAmount = (expectedAmount * 25) / 10000; // 0.25% fee
        uint256 winnerAmount = expectedAmount - feeAmount;
        assertEq(wordFunToken.balanceOf(winner) - balanceBefore, winnerAmount);
    }

    function testCancelPool() public {
        // 创建池子
        vm.startPrank(creator);
        wordFunToken.approve(address(gambling), 1000 * 10**18);
        gambling.createPool(100 * 10**18, 5000 * 10**18, 10, "Test game", 1000 * 10**18);
        vm.stopPrank();
        
        // 取消池子
        uint256 balanceBefore = wordFunToken.balanceOf(creator);
        vm.startPrank(creator);
        gambling.cancelPool(0);
        vm.stopPrank();
        
        // 验证取消
        WordGambling.Pool memory pool = gambling.getPool(0);
        assertEq(uint256(pool.status), uint256(WordGambling.PoolStatus.Cancelled));
        assertEq(wordFunToken.balanceOf(creator) - balanceBefore, 1000 * 10**18);
    }

    function test_RevertWhen_CancelPoolWithDeposits() public {
        // 创建池子
        vm.startPrank(creator);
        wordFunToken.approve(address(gambling), 1000 * 10**18);
        gambling.createPool(100 * 10**18, 5000 * 10**18, 10, "Test game", 1000 * 10**18);
        vm.stopPrank();
        
        // 挑战者充值
        vm.startPrank(challenger1);
        wordFunToken.approve(address(gambling), 500 * 10**18);
        gambling.depositToPool(0, 500 * 10**18);
        vm.stopPrank();
        
        // 尝试取消池子（应该失败）
        vm.startPrank(creator);
        vm.expectRevert("Cannot cancel after challenger deposits");
        gambling.cancelPool(0);
        vm.stopPrank();
    }

    function test_RevertWhen_CreatorAsChallenger() public {
        // 创建池子
        vm.startPrank(creator);
        wordFunToken.approve(address(gambling), 1000 * 10**18);
        gambling.createPool(100 * 10**18, 5000 * 10**18, 10, "Test game", 1000 * 10**18);
        
        // 尝试作为挑战者充值（应该失败）
        wordFunToken.approve(address(gambling), 500 * 10**18);
        vm.expectRevert("Creator cannot be challenger");
        gambling.depositToPool(0, 500 * 10**18);
        vm.stopPrank();
    }

    function test_RevertWhen_InsufficientDeposit() public {
        // 创建池子
        vm.startPrank(creator);
        wordFunToken.approve(address(gambling), 1000 * 10**18);
        gambling.createPool(100 * 10**18, 5000 * 10**18, 10, "Test game", 1000 * 10**18);
        vm.stopPrank();
        
        // 尝试充值不足金额（应该失败）
        vm.startPrank(challenger1);
        wordFunToken.approve(address(gambling), 50 * 10**18);
        vm.expectRevert("Deposit too small");
        gambling.depositToPool(0, 50 * 10**18);
        vm.stopPrank();
    }

    function test_RevertWhen_ExceedMaxDeposits() public {
        // 创建池子
        vm.startPrank(creator);
        wordFunToken.approve(address(gambling), 1000 * 10**18);
        gambling.createPool(100 * 10**18, 1000 * 10**18, 10, "Test game", 1000 * 10**18);
        vm.stopPrank();
        
        // 挑战者充值到上限
        vm.startPrank(challenger1);
        wordFunToken.approve(address(gambling), 1000 * 10**18);
        gambling.depositToPool(0, 1000 * 10**18);
        vm.stopPrank();
        
        // 尝试超额充值（应该失败）
        vm.startPrank(challenger2);
        wordFunToken.approve(address(gambling), 100 * 10**18);
        vm.expectRevert("Exceeds max challenger deposits");
        gambling.depositToPool(0, 100 * 10**18);
        vm.stopPrank();
    }

    function testGetChallengerDeposits() public {
        // 创建池子
        vm.startPrank(creator);
        wordFunToken.approve(address(gambling), 1000 * 10**18);
        gambling.createPool(100 * 10**18, 5000 * 10**18, 10, "Test game", 1000 * 10**18);
        vm.stopPrank();
        
        // 多个挑战者充值
        vm.startPrank(challenger1);
        wordFunToken.approve(address(gambling), 500 * 10**18);
        gambling.depositToPool(0, 500 * 10**18);
        vm.stopPrank();
        
        vm.startPrank(challenger2);
        wordFunToken.approve(address(gambling), 300 * 10**18);
        gambling.depositToPool(0, 300 * 10**18);
        vm.stopPrank();
        
        // 获取充值记录
        WordGambling.ChallengerDeposit[] memory deposits = gambling.getChallengerDeposits(0);
        assertEq(deposits.length, 2);
        assertEq(deposits[0].challenger, challenger1);
        assertEq(deposits[0].amount, 500 * 10**18);
        assertEq(deposits[1].challenger, challenger2);
        assertEq(deposits[1].amount, 300 * 10**18);
    }

    function testPlatformFee() public {
        // 创建池子
        vm.startPrank(creator);
        wordFunToken.approve(address(gambling), 1000 * 10**18);
        gambling.createPool(100 * 10**18, 5000 * 10**18, 10, "Test game", 1000 * 10**18);
        vm.stopPrank();
        
        // 挑战者充值
        vm.startPrank(challenger1);
        wordFunToken.approve(address(gambling), 500 * 10**18);
        gambling.depositToPool(0, 500 * 10**18);
        vm.stopPrank();
        
        // 结算池子
        uint256 ownerBalanceBefore = wordFunToken.balanceOf(owner);
        vm.startPrank(creator);
        gambling.settlePool(0, winner);
        vm.stopPrank();
        
        // 验证平台费用
        uint256 totalAmount = 1500 * 10**18;
        uint256 expectedFee = (totalAmount * 25) / 10000; // 0.25%
        assertEq(wordFunToken.balanceOf(owner) - ownerBalanceBefore, expectedFee);
    }

    function testInsufficientAllowance() public {
        vm.startPrank(creator);
        // 不授权就尝试创建池子（应该失败）
        vm.expectRevert("Insufficient WordFunToken allowance");
        gambling.createPool(100 * 10**18, 5000 * 10**18, 10, "Test game", 1000 * 10**18);
        vm.stopPrank();
    }

    function testInsufficientBalance() public {
        vm.startPrank(creator);
        // 授权但余额不足（应该失败）
        wordFunToken.approve(address(gambling), 1000000 * 10**18); // 授权100万 WordFunToken
        vm.expectRevert("Insufficient WordFunToken balance");
        gambling.createPool(100 * 10**18, 5000 * 10**18, 10, "Test game", 1000000 * 10**18); // 尝试存入100万 WordFunToken
        vm.stopPrank();
    }

    function test_RevertWhen_DuplicateParticipation() public {
        // 创建池子
        vm.startPrank(creator);
        wordFunToken.approve(address(gambling), 1000 * 10**18);
        gambling.createPool(100 * 10**18, 5000 * 10**18, 10, "Test game", 1000 * 10**18);
        vm.stopPrank();
        
        // 挑战者第一次充值
        vm.startPrank(challenger1);
        wordFunToken.approve(address(gambling), 500 * 10**18);
        gambling.depositToPool(0, 500 * 10**18);
        vm.stopPrank();
        
        // 尝试第二次充值（应该失败）
        vm.startPrank(challenger1);
        wordFunToken.approve(address(gambling), 300 * 10**18);
        vm.expectRevert("Not eligible to participate");
        gambling.depositToPool(0, 300 * 10**18);
        vm.stopPrank();
    }

    function test_RevertWhen_MaxChallengersReached() public {
        // 创建池子，最大挑战者数量为2
        vm.startPrank(creator);
        wordFunToken.approve(address(gambling), 1000 * 10**18);
        gambling.createPool(100 * 10**18, 5000 * 10**18, 2, "Test game", 1000 * 10**18);
        vm.stopPrank();
        
        // 第一个挑战者充值
        vm.startPrank(challenger1);
        wordFunToken.approve(address(gambling), 500 * 10**18);
        gambling.depositToPool(0, 500 * 10**18);
        vm.stopPrank();
        
        // 第二个挑战者充值
        vm.startPrank(challenger2);
        wordFunToken.approve(address(gambling), 300 * 10**18);
        gambling.depositToPool(0, 300 * 10**18);
        vm.stopPrank();
        
        // 检查池子状态是否为 Full
        WordGambling.Pool memory pool = gambling.getPool(0);
        assertEq(uint256(pool.status), uint256(WordGambling.PoolStatus.Full));
        
        // 第三个挑战者尝试充值（应该失败）
        address challenger3 = address(6);
        wordFunToken.transfer(challenger3, 100000 * 10**18);
        vm.startPrank(challenger3);
        wordFunToken.approve(address(gambling), 200 * 10**18);
        vm.expectRevert("Pool is not active");
        gambling.depositToPool(0, 200 * 10**18);
        vm.stopPrank();
    }

    function testCanParticipate() public {
        // 创建池子
        vm.startPrank(creator);
        wordFunToken.approve(address(gambling), 1000 * 10**18);
        gambling.createPool(100 * 10**18, 5000 * 10**18, 5, "Test game", 1000 * 10**18);
        vm.stopPrank();
        
        // 检查新挑战者是否有资格参与
        assertTrue(gambling.canParticipate(0, challenger1));
        assertTrue(gambling.canParticipate(0, challenger2));
        
        // 挑战者参与后，再次检查资格
        vm.startPrank(challenger1);
        wordFunToken.approve(address(gambling), 500 * 10**18);
        gambling.depositToPool(0, 500 * 10**18);
        vm.stopPrank();
        
        assertFalse(gambling.canParticipate(0, challenger1)); // 已参与，不能再参与
        assertTrue(gambling.canParticipate(0, challenger2));  // 未参与，可以参与
    }

    function testHasParticipated() public {
        // 创建池子
        vm.startPrank(creator);
        wordFunToken.approve(address(gambling), 1000 * 10**18);
        gambling.createPool(100 * 10**18, 5000 * 10**18, 5, "Test game", 1000 * 10**18);
        vm.stopPrank();
        
        // 检查初始状态
        assertFalse(gambling.hasParticipated(0, challenger1));
        assertFalse(gambling.hasParticipated(0, challenger2));
        
        // 挑战者参与
        vm.startPrank(challenger1);
        wordFunToken.approve(address(gambling), 500 * 10**18);
        gambling.depositToPool(0, 500 * 10**18);
        vm.stopPrank();
        
        // 检查参与状态
        assertTrue(gambling.hasParticipated(0, challenger1));
        assertFalse(gambling.hasParticipated(0, challenger2));
    }
} 