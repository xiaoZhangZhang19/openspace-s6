import hashlib
import time

def find_hash_with_prefix(base_string, algorithm='sha256', prefix='0000'):
    """
    单独检测指定前缀的哈希值
    """
    start_time = time.perf_counter()
    nonce = 0
    
    while True:
        input_str = f"{base_string}{nonce}"
        hash_obj = hashlib.new(algorithm)
        hash_obj.update(input_str.encode('utf-8'))
        hex_digest = hash_obj.hexdigest()
        
        if hex_digest.startswith(prefix):
            elapsed_time = time.perf_counter() - start_time
            return {
                "nonce": nonce,
                "time_cost": f"{elapsed_time:.6f} seconds",
                "hash_content": input_str,
                "hash_value": hex_digest
            }
        
        nonce += 1

def run_sequential_detection(base_string, prefixes):
    """
    按顺序执行多前缀检测（先处理小前缀，再处理大前缀）
    """
    results = {}
    for prefix in prefixes:
        print(f"\n正在检测前缀 '{prefix}'...")
        result = find_hash_with_prefix(base_string, prefix=prefix)
        results[prefix] = result
        print(f"找到匹配！Nonce: {result['nonce']}")
        print(f"耗时: {result['time_cost']}")
        print(f"内容: {result['hash_content']}")
        print(f"哈希: {result['hash_value']}")
    
    return results

# 使用示例
if __name__ == "__main__":
    target_string = "xiaojian"
    
    # 分阶段检测（先4个0，后5个0）
    print("=== 分阶段检测开始 ===")
    run_sequential_detection(target_string, ['0000', '00000', '000000', '0000000'])