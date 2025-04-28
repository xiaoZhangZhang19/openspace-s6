import hashlib
import time
import rsa

def generate_rsa_keypair():
    """生成RSA公私钥对"""
    (public_key, private_key) = rsa.newkeys(2048)
    return public_key, private_key

def find_pow_nonce(nickname, prefix='0000'):
    """工作量证明：寻找符合条件的nonce"""
    nonce = 0
    while True:
        data = f"{nickname}{nonce}".encode('utf-8')
        hex_digest = hashlib.sha256(data).hexdigest()
        
        if hex_digest.startswith(prefix):
            return nonce, hex_digest
        nonce += 1

def sign_with_private_key(private_key, message):
    """使用私钥签名"""
    signature = rsa.sign(message.encode('utf-8'), private_key, 'SHA-256')
    return signature

def verify_with_public_key(public_key, message, signature):
    """使用公钥验证签名"""
    try:
        rsa.verify(message.encode('utf-8'), signature, public_key)
        return True
    except rsa.VerificationError:
        return False

if __name__ == "__main__":
    # 生成密钥对
    print("正在生成RSA密钥对...")
    public_key, private_key = generate_rsa_keypair()
    print("密钥生成完成！")

    # 用户输入昵称
    nickname = input("请输入您的昵称: ")

    # 执行工作量证明
    print("开始寻找符合4个0前缀的哈希值...")
    start_time = time.time()
    nonce, valid_hash = find_pow_nonce(nickname)
    elapsed_time = time.time() - start_time

    # 构造待签名消息
    message = f"{nickname}{nonce}"
    
    # 私钥签名
    print("正在进行签名...")
    signature = sign_with_private_key(private_key, message)
    
    # 验证签名
    print("验证签名...")
    is_valid = verify_with_public_key(public_key, message, signature)

    # 输出结果
    print("=== 最终结果 ===")
    print(f"昵称: {nickname}")
    print(f"Nonce: {nonce}")
    print(f"哈希值: {valid_hash}")
    print(f"签名验证: {'成功' if is_valid else '失败'}")
    print(f"耗时: {elapsed_time:.4f}秒")

    # 测试篡改验证
    print("=== 篡改测试 ===")
    tampered_message = message + "tampered"
    is_tampered_valid = verify_with_public_key(public_key, tampered_message, signature)
    print(f"篡改验证结果: {'成功' if is_tampered_valid else '失败'}")