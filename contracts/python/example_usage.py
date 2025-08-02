#!/usr/bin/env python3
"""
WordGambling合约使用示例
演示如何使用WordGamblingClient进行基本操作
"""

from wordgambling_client import WordGamblingClient

def main():
    # 配置参数 - 请根据实际情况修改
    RPC_URL = "http://localhost:8545"
    PRIVATE_KEY = "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
    WORD_FUN_TOKEN_ADDRESS = "0xb185E9f6531BA9877741022C92CE858cDCc5760E"
    WORD_GAMBLING_ADDRESS = "0xAe120F0df055428E45b264E7794A18c54a2a3fAF"  # 请填入实际部署的地址
    
    print("=== WordGambling合约使用示例 ===")
    
    try:
        # 初始化客户端
        client = WordGamblingClient(
            RPC_URL,
            PRIVATE_KEY,
            WORD_FUN_TOKEN_ADDRESS,
            WORD_GAMBLING_ADDRESS
        )
        
        # # 示例1: 查看账户余额
        print("\n--- 示例1: 查看账户余额 ---")
        client.get_balance()

        
        # 示例2: 创建游戏池子
        print("\n--- 示例2: 创建游戏池子 ---")
        pool_id = client.create_pool(
            max_challengers=10,
            game_description="test",
            creator_deposit=100 * 10**18,  # 100 tokens
            settlement_time=3600  # 1小时结算时间
        )
    
    
        if pool_id is not None:
            # 示例3: 查看池子详情
            print("\n--- 示例3: 查看池子详情 ---")
            client.get_pool_details(pool_id)
            
            # 示例4: 查看当前挑战费用
            print("\n--- 示例4: 查看当前挑战费用 ---")
            client.get_current_challenge_fee(pool_id)
            
            # 示例5: 检查是否可以结算失败
            print("\n--- 示例5: 检查结算失败资格 ---")
            client.can_settle_failure(pool_id)
            
            # 示例6: 获取剩余结算时间
            print("\n--- 示例6: 获取剩余结算时间 ---")
            client.get_remaining_settlement_time(pool_id)
            
            # 示例7: 检查参与资格
            print("\n--- 示例7: 检查参与资格 ---")
            client.can_participate(pool_id, client.address)
            
            # 示例8: 向池子充值（作为挑战者）
            print("\n--- 示例8: 向池子充值 ---")
            success = client.deposit_to_pool(pool_id)
            
            if success:
                # 示例9: 再次查看池子详情（查看变化）
                print("\n--- 示例9: 充值后的池子详情 ---")
                client.get_pool_details(pool_id)
                
                # 示例10: 查看新的挑战费用
                print("\n--- 示例10: 新的挑战费用 ---")
                client.get_current_challenge_fee(pool_id)
                
                # 示例11: 结算池子（成功）
                print("\n--- 示例11: 结算池子（成功） ---")
                client.settle_pool(pool_id, client.address, True)
                
                # 示例12: 尝试结算失败（需要等待时间）
                print("\n--- 示例12: 尝试结算失败 ---")
                if client.can_settle_failure(pool_id):
                    client.settle_pool(pool_id, client.address, False)
                else:
                    print("时间未到，无法结算失败")
        
        print("\n=== 示例完成 ===")
        
    except Exception as e:
        print(f"错误: {e}")
        print("请检查配置参数是否正确")

if __name__ == "__main__":
    main() 