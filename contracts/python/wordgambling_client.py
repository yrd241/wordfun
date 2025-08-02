#!/usr/bin/env python3
"""
WordGambling合约客户端
使用web3.py库调用WordGambling合约的各个接口
"""

import json
import os
from web3 import Web3
from eth_account import Account

class WordGamblingClient:
    def __init__(self, rpc_url: str, private_key: str, word_fun_token_address: str, word_gambling_address: str):
        self.w3 = Web3(Web3.HTTPProvider(rpc_url))
        self.account = Account.from_key(private_key)
        self.address = self.account.address
        
        if not self.w3.is_connected():
            raise Exception("无法连接到RPC节点")
        
        print(f"连接到RPC节点: {rpc_url}")
        print(f"账户地址: {self.address}")
        
        # 加载合约ABI
        self.word_fun_token_abi = self._load_abi("WordFunToken")
        self.word_gambling_abi = self._load_abi("WordGambling")
        
        # 初始化合约实例
        self.word_fun_token = self.w3.eth.contract(
            address=word_fun_token_address,
            abi=self.word_fun_token_abi
        )
        
        self.word_gambling = self.w3.eth.contract(
            address=word_gambling_address,
            abi=self.word_gambling_abi
        )
        
        print(f"WordFunToken合约地址: {word_fun_token_address}")
        print(f"WordGambling合约地址: {word_gambling_address}")
    
    def _load_abi(self, contract_name: str):
        try:
            # 尝试多个可能的路径
            possible_paths = [
                f"out/{contract_name}.sol/{contract_name}.json",
                f"../out/{contract_name}.sol/{contract_name}.json",
                f"../../out/{contract_name}.sol/{contract_name}.json",
                f"out/{contract_name}.sol/wordGambling.abi" if contract_name == "WordGambling" else None
            ]
            
            for path in possible_paths:
                if path and os.path.exists(path):
                    print(f"找到ABI文件: {path}")
                    with open(path, 'r') as f:
                        if path.endswith('.json'):
                            artifact = json.load(f)
                            abi = artifact.get('abi', [])
                        else:
                            # 如果是.abi文件，直接读取JSON
                            abi = json.load(f)
                        
                        if abi:
                            print(f"成功加载 {contract_name} ABI，包含 {len(abi)} 个函数")
                            return abi
                        else:
                            print(f"警告: {contract_name} ABI为空")
            
            print(f"错误: 无法找到 {contract_name} 的ABI文件")
            print(f"尝试的路径: {possible_paths}")
            
        except Exception as e:
            print(f"警告: 无法加载{contract_name}的ABI: {e}")
        
        # 如果无法加载，返回基本的ABI
        print(f"使用基本ABI for {contract_name}")
        return []
    
    def _send_transaction(self, contract, function_name: str, *args):
        try:
            function = getattr(contract.functions, function_name)
            transaction = function(*args).build_transaction({
                'from': self.address,
                'nonce': self.w3.eth.get_transaction_count(self.address),
                'gas': 500000,
                'gasPrice': self.w3.eth.gas_price,
            })
            
            signed_txn = self.w3.eth.account.sign_transaction(transaction, self.account.key)
            tx_hash = self.w3.eth.send_raw_transaction(signed_txn.rawTransaction)
            print(f"交易已发送: {tx_hash.hex()}")
            
            receipt = self.w3.eth.wait_for_transaction_receipt(tx_hash)
            if receipt.status == 1:
                print(f"交易成功确认，区块号: {receipt.blockNumber}")
                return tx_hash.hex()
            else:
                print("交易失败")
                return None
                
        except Exception as e:
            print(f"交易发送失败: {e}")
            return None
    
    def get_balance(self):
        eth_balance = self.w3.eth.get_balance(self.address)
        token_balance = self.word_fun_token.functions.balanceOf(self.address).call()
        
        print(f"ETH余额: {self.w3.from_wei(eth_balance, 'ether')} ETH")
        print(f"WordFunToken余额: {token_balance / 10**18} tokens")
        
        return eth_balance, token_balance
    
    def approve_tokens(self, spender: str, amount: int) -> bool:
        print(f"授权 {spender} 使用 {amount / 10**18} WordFunToken")
        
        tx_hash = self._send_transaction(
            self.word_fun_token,
            'approve',
            spender,
            amount
        )
        
        return tx_hash is not None
    
    def create_pool(self, max_challengers: int, game_description: str, creator_deposit: int):
        print(f"创建池子: 最大挑战者={max_challengers}, 描述='{game_description}', 存款={creator_deposit / 10**18} tokens")
        
        if not self.approve_tokens(self.word_gambling.address, creator_deposit):
            print("授权失败")
            return None
        
        tx_hash = self._send_transaction(
            self.word_gambling,
            'createPool',
            max_challengers,
            game_description,
            creator_deposit
        )
        
        if tx_hash:
            pool_count = self.word_gambling.functions.getPoolCount().call()
            pool_id = pool_count - 1
            print(f"池子创建成功，ID: {pool_id}")
            return pool_id
        
        return None
    
    def deposit_to_pool(self, pool_id: int) -> bool:
        try:
            challenge_fee = self.word_gambling.functions.getCurrentChallengeFee(pool_id).call()
            print(f"池子 {pool_id} 的当前挑战费用: {challenge_fee / 10**18} tokens")
            
            if not self.approve_tokens(self.word_gambling.address, challenge_fee):
                print("授权失败")
                return False
            
            tx_hash = self._send_transaction(
                self.word_gambling,
                'depositToPool',
                pool_id
            )
            
            if tx_hash:
                print(f"成功向池子 {pool_id} 充值 {challenge_fee / 10**18} tokens")
                return True
            
            return False
            
        except Exception as e:
            print(f"充值失败: {e}")
            return False
    
    def settle_pool(self, pool_id: int, winner: str, is_success: bool) -> bool:
        print(f"结算池子 {pool_id}: 获胜者={winner}, 成功={is_success}")
        
        tx_hash = self._send_transaction(
            self.word_gambling,
            'settlePool',
            pool_id,
            winner,
            is_success
        )
        
        return tx_hash is not None
    
    def get_pool_details(self, pool_id: int):
        try:
            details = self.word_gambling.functions.getPoolDetails(pool_id).call()
            
            pool_info = {
                'creator': details[0],
                'creator_deposit': details[1] / 10**18,
                'total_challenger_deposits': details[2] / 10**18,
                'status': details[3],
                'game_description': details[7],
                'max_challengers': details[8],
                'current_challenger_count': details[9],
                'challenge_fee_percentage': details[10] / 100
            }
            
            print(f"池子 {pool_id} 详情:")
            print(f"  创建者: {pool_info['creator']}")
            print(f"  创建者存款: {pool_info['creator_deposit']} tokens")
            print(f"  挑战者总存款: {pool_info['total_challenger_deposits']} tokens")
            print(f"  状态: {pool_info['status']}")
            print(f"  游戏描述: {pool_info['game_description']}")
            print(f"  最大挑战者: {pool_info['max_challengers']}")
            print(f"  当前挑战者: {pool_info['current_challenger_count']}")
            print(f"  挑战费用比例: {pool_info['challenge_fee_percentage']}%")
            
            return pool_info
            
        except Exception as e:
            print(f"获取池子详情失败: {e}")
            return None
    
    def get_current_challenge_fee(self, pool_id: int):
        try:
            fee = self.word_gambling.functions.getCurrentChallengeFee(pool_id).call()
            print(f"池子 {pool_id} 的当前挑战费用: {fee / 10**18} tokens")
            return fee
        except Exception as e:
            print(f"获取挑战费用失败: {e}")
            return None
    
    def can_participate(self, pool_id: int, challenger: str) -> bool:
        try:
            can_participate = self.word_gambling.functions.canParticipate(pool_id, challenger).call()
            print(f"地址 {challenger} 是否可以参与池子 {pool_id}: {can_participate}")
            return can_participate
        except Exception as e:
            print(f"检查参与资格失败: {e}")
            return False


# def main():
#     """主函数 - 演示如何使用WordGambling客户端"""
    
#     # 配置参数
#     RPC_URL = "http://localhost:8545"  # 本地anvil节点
#     PRIVATE_KEY = "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"  # 测试私钥
#     WORD_FUN_TOKEN_ADDRESS = "0xb185E9f6531BA9877741022C92CE858cDCc5760E"  # 部署的WordFunToken地址
#     WORD_GAMBLING_ADDRESS = "0xAe120F0df055428E45b264E7794A18c54a2a3fAF"  # 需要填入部署的WordGambling地址
    
#     print("=== WordGambling合约客户端演示 ===")
    
#     try:
#         # 初始化客户端
#         client = WordGamblingClient(
#             RPC_URL,
#             PRIVATE_KEY,
#             WORD_FUN_TOKEN_ADDRESS,
#             WORD_GAMBLING_ADDRESS
#         )
        
#         # 获取余额
#         print("\n1. 获取账户余额")
#         client.get_balance()
        
#         # 创建池子
#         print("\n2. 创建池子")
#         pool_id = client.create_pool(
#             max_challengers=5,
#             game_description="测试游戏：谁能猜中这个数字？",
#             creator_deposit=1000 * 10**18  # 1000 tokens
#         )
        
#         if pool_id is not None:
#             # 获取池子详情
#             print("\n3. 获取池子详情")
#             client.get_pool_details(pool_id)
            
#             # 获取当前挑战费用
#             print("\n4. 获取当前挑战费用")
#             client.get_current_challenge_fee(pool_id)
            
#             # 检查参与资格
#             print("\n5. 检查参与资格")
#             client.can_participate(pool_id, client.address)
            
#             # 向池子充值
#             print("\n6. 向池子充值")
#             client.deposit_to_pool(pool_id)
            
#             # 结算池子
#             print("\n7. 结算池子")
#             client.settle_pool(pool_id, client.address, True)  # 成功
        
#     except Exception as e:
#         print(f"错误: {e}")


# if __name__ == "__main__":
#     main() 