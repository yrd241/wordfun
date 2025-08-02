// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/WordFunToken.sol";

contract WordFunTokenTest is Test {
    WordFunToken public token;
    address public owner = address(1);
    address public user1 = address(2);
    address public user2 = address(3);
    
    function setUp() public {
        vm.startPrank(owner);
        token = new WordFunToken();
        vm.stopPrank();
    }

    function testTokenInfo() public {
        assertEq(token.name(), "wordfun");
        assertEq(token.symbol(), "word");
        assertEq(token.decimals(), 18);
        assertEq(token.totalSupply(), 1_000_000_000 * 10**18);
    }

    function testInitialBalance() public {
        assertEq(token.balanceOf(owner), 1_000_000_000 * 10**18);
        assertEq(token.balanceOf(user1), 0);
    }

    function testTransfer() public {
        uint256 amount = 1000 * 10**18;
        
        vm.startPrank(owner);
        token.transfer(user1, amount);
        vm.stopPrank();
        
        assertEq(token.balanceOf(user1), amount);
        assertEq(token.balanceOf(owner), 1_000_000_000 * 10**18 - amount);
    }

    function testMint() public {
        uint256 amount = 1000 * 10**18;
        
        vm.startPrank(owner);
        token.mint(user1, amount);
        vm.stopPrank();
        
        assertEq(token.balanceOf(user1), amount);
        assertEq(token.totalSupply(), 1_000_000_000 * 10**18 + amount);
    }

    function testBurn() public {
        uint256 amount = 1000 * 10**18;
        
        vm.startPrank(owner);
        token.burn(amount);
        vm.stopPrank();
        
        assertEq(token.balanceOf(owner), 1_000_000_000 * 10**18 - amount);
        assertEq(token.totalSupply(), 1_000_000_000 * 10**18 - amount);
    }

    function testBurnFrom() public {
        uint256 amount = 1000 * 10**18;
        
        // 先转移一些代币给 user1
        vm.startPrank(owner);
        token.transfer(user1, amount);
        vm.stopPrank();
        
        // 从 user1 销毁代币
        vm.startPrank(owner);
        token.burnFrom(user1, amount);
        vm.stopPrank();
        
        assertEq(token.balanceOf(user1), 0);
        assertEq(token.totalSupply(), 1_000_000_000 * 10**18 - amount);
    }

    function test_RevertWhen_NonOwnerMint() public {
        vm.startPrank(user1);
        vm.expectRevert();
        token.mint(user2, 1000 * 10**18);
        vm.stopPrank();
    }

    function test_RevertWhen_NonOwnerBurn() public {
        vm.startPrank(user1);
        vm.expectRevert();
        token.burn(1000 * 10**18);
        vm.stopPrank();
    }

    function test_RevertWhen_NonOwnerBurnFrom() public {
        vm.startPrank(user1);
        vm.expectRevert();
        token.burnFrom(user2, 1000 * 10**18);
        vm.stopPrank();
    }
} 