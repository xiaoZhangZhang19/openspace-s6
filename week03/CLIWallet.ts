import { createWalletClient, createPublicClient, http, parseEther, formatEther, type Address, type Hash } from 'viem';
import { generatePrivateKey, privateKeyToAccount } from 'viem/accounts';
import { sepolia } from 'viem/chains';
import * as readlineSync from 'readline-sync';
import * as dotenv from 'dotenv';

dotenv.config();

const RPC_URL = process.env.ETH_RPC_URL;
if (!RPC_URL) {
    throw new Error('ETH_RPC_URL not found in .env file');
}

// 创建 viem 客户端
const publicClient = createPublicClient({
    chain: sepolia,
    transport: http(RPC_URL)
});

const walletClient = createWalletClient({
    chain: sepolia,
    transport: http(RPC_URL)
});

// ERC20 代币 ABI
const erc20Abi = [
    {
        "constant": false,
        "inputs": [
            {
                "name": "_to",
                "type": "address"
            },
            {
                "name": "_value",
                "type": "uint256"
            }
        ],
        "name": "transfer",
        "outputs": [
            {
                "name": "",
                "type": "bool"
            }
        ],
        "payable": false,
        "stateMutability": "nonpayable",
        "type": "function"
    },
    {
        "constant": true,
        "inputs": [
            {
                "name": "_owner",
                "type": "address"
            }
        ],
        "name": "balanceOf",
        "outputs": [
            {
                "name": "balance",
                "type": "uint256"
            }
        ],
        "payable": false,
        "stateMutability": "view",
        "type": "function"
    }
] as const;

async function main() {
    console.log('=== 命令行钱包工具 ===');
    console.log('1. 生成新钱包');
    console.log('2. 查询 ETH 余额');
    console.log('3. 查询 ERC20 代币余额');
    console.log('4. 发送 ERC20 代币');
    console.log('5. 退出');

    let account: ReturnType<typeof privateKeyToAccount> | null = null;

    while (true) {
        const choice = readlineSync.question('\n请选择操作 (1-5): ');

        switch (choice) {
            case '1':
                account = await generateWallet();
                break;
            case '2':
                await checkEthBalance(account);
                break;
            case '3':
                await checkTokenBalance(account);
                break;
            case '4':
                await sendToken(account);
                break;
            case '5':
                console.log('再见！');
                return;
            default:
                console.log('无效的选择，请重试');
        }
    }
}

async function generateWallet() {
    // 生成私钥
    const privateKey = generatePrivateKey();
    // 将私钥转换为账户
    const account = privateKeyToAccount(privateKey);
    
    console.log('\n=== 新钱包信息 ===');
    console.log(`私钥: ${privateKey}`);
    console.log(`地址: ${account.address}`);
    
    return account;
}

async function checkEthBalance(account: ReturnType<typeof privateKeyToAccount> | null) {
    if (!account) {
        console.log('请先生成钱包！');
        return;
    }

    try {
        const balance = await publicClient.getBalance({ address: account.address });
        console.log(`\nETH 余额: ${formatEther(balance)} ETH`);
    } catch (error) {
        console.error('获取余额失败:', error);
    }
}

async function checkTokenBalance(account: ReturnType<typeof privateKeyToAccount> | null) {
    if (!account) {
        console.log('请先生成钱包！');
        return;
    }

    const tokenAddress = readlineSync.question('请输入代币合约地址: ') as Address;

    try {
        const balance = await publicClient.readContract({
            address: tokenAddress,
            abi: erc20Abi,
            functionName: 'balanceOf',
            args: [account.address]
        });
        console.log(`\n代币余额: ${balance.toString()}`);
    } catch (error) {
        console.error('获取代币余额失败:', error);
    }
}

async function sendToken(account: ReturnType<typeof privateKeyToAccount> | null) {
    if (!account) {
        console.log('请先生成钱包！');
        return;
    }

    const tokenAddress = readlineSync.question('请输入代币合约地址: ') as Address;
    const to = readlineSync.question('请输入接收方地址: ') as Address;
    const amount = readlineSync.question('请输入发送数量: ');

    try {
        // 获取当前 gas 价格
        const [maxFeePerGas, maxPriorityFeePerGas] = await Promise.all([
            publicClient.getGasPrice(),
            publicClient.estimateMaxPriorityFeePerGas()
        ]);

        // 构建 EIP-1559 交易
        const hash = await walletClient.writeContract({
            account,
            address: tokenAddress,
            abi: erc20Abi,
            functionName: 'transfer',
            args: [to, BigInt(amount)],
            maxFeePerGas,
            maxPriorityFeePerGas
        });

        console.log('\n=== 交易信息 ===');
        console.log(`交易哈希: ${hash}`);
        console.log(`最大 gas 价格: ${formatEther(maxFeePerGas)} ETH`);
        console.log(`最大优先 gas 价格: ${formatEther(maxPriorityFeePerGas)} ETH`);

        // 等待交易确认
        console.log('\n等待交易确认...');
        const receipt = await publicClient.waitForTransactionReceipt({ hash });
        console.log(`交易已确认，区块号: ${receipt.blockNumber}`);
        console.log(`交易已确认，交易哈希: ${receipt.transactionHash}`);
        console.log(`交易已确认，交易索引: ${receipt.transactionIndex}`);
    } catch (error) {
        console.error('发送交易失败:', error);
    }
}

main().catch(console.error); 