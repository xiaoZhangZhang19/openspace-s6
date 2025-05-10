import { getContract, parseAbi } from 'viem'
import { ERC20abi } from './abi.js'
import { publicClient } from './client.js'
import { parseAbiItem } from 'viem/utils'

const abiERC20 = parseAbi([
    'function name() public view returns (string memory)',
    'event Transfer(address indexed from, address indexed to, uint256 value)',
    'event Approval(address indexed owner, address indexed spender, uint256 value)',
    'function transfer(address to, uint256 value) external returns (bool)',
    'function balanceOf(address account) external view returns (uint256)',
])

//创建新事件过滤器
async function fetchTransferEvent() {
    try {
        // 获取当前区块高度
        const currentBlock = await publicClient.getBlockNumber()
        console.log('Current block:', currentBlock)
        
        // 使用最近的区块范围
        const fromBlock = currentBlock - 100n  // 从100个区块前开始
        const toBlock = currentBlock           // 到当前区块
        
        const filter = await publicClient.createEventFilter({
            address: '0x319dd63e0ac72e7ac74443029d074032c043460f',
            event: abiERC20[1],
            fromBlock,
            toBlock
        })

        const logs = await publicClient.getFilterLogs({ filter });

        logs.forEach((log)=>{
            console.log(`转USDT从${log.args.from}到${log.args.to},共计${log.args.value},hash值是${log.transactionHash}`);
        })
    } catch (error) {
        console.error('Error fetching events:', error)
    }
}
// fetchTransferEvent();

//创建合约事件过滤器
async function createContractEventFilter() {
    // 获取当前区块高度
    const currentBlock = await publicClient.getBlockNumber()
    console.log('Current block:', currentBlock)
    // 使用最近的区块范围
    const fromBlock = currentBlock - 100000n  // 从100个区块前开始
    console.log('from block:', fromBlock);
    const toBlock = currentBlock           // 到当前区块
    console.log('to block:', toBlock);
    
    const filter = await publicClient.createContractEventFilter({
        abi: ERC20abi,
        address: '0x319dd63e0ac72e7ac74443029d074032c043460f',
        eventName: 'Transfer',
        fromBlock: fromBlock, 
        toBlock: toBlock
    })

    const logs = await publicClient.getFilterLogs({ filter });

    logs.forEach((log)=>{
        console.log(`转USDT从${log.args.from}到${log.args.to},共计${log.args.value},hash值是${log.transactionHash}`);
    })
}
// createContractEventFilter();

//监听事件
async function watchTransferEvent() {
    try {
        console.log('Starting to fetch events...')
        
        // 测试连接
        const chainId = await publicClient.getChainId()
        console.log('Connected to chain ID:', chainId)
        
        // 获取当前区块高度
        const currentBlock = await publicClient.getBlockNumber()
        console.log('Current block:', currentBlock)
        
        // 使用更大的区块范围
        const fromBlock = currentBlock - 1000n  // 查询最近1000个区块
        const toBlock = currentBlock
        
        console.log('Searching blocks from', fromBlock, 'to', toBlock)
        
        // 尝试获取任何类型的事件
        const logs = await publicClient.getLogs({
            address: '0xdAC17F958D2ee523a2206206994597C13D831ec7',
            fromBlock,
            toBlock
        })
        
        console.log('Number of all logs found:', logs.length)
        
        if (logs.length === 0) {
            console.log('No events found in the specified block range')
            return
        }
        
        // 打印所有找到的事件
        logs.forEach((log) => {
            console.log('Event found:', {
                address: log.address,
                topics: log.topics,
                data: log.data,
                transactionHash: log.transactionHash
            })
        })
        
    } catch (error) {
        console.error('Error details:', error)
    }
}

// 调用函数
// watchTransferEvent()

async function watchTransferEvent2() {
    try {
        console.log('Starting to fetch events...')
        
        const currentBlock = await publicClient.getBlockNumber()
        console.log('Current block:', currentBlock)
        
        // 使用更大的区块范围
        const fromBlock = currentBlock - 10000n  // 查询最近10000个区块
        const toBlock = currentBlock
        
        console.log('Searching blocks from', fromBlock, 'to', toBlock)
        
        // 获取所有事件，不限制合约地址
        const logs = await publicClient.getLogs({
            fromBlock,
            toBlock
        })
        
        console.log('Number of all logs found:', logs.length)
        
        if (logs.length === 0) {
            console.log('No events found in the specified block range')
            return
        }
        
        // 打印所有找到的事件，特别关注 Transfer 事件
        logs.forEach((log) => {
            // 检查是否是 Transfer 事件（通过 topics[0] 判断）
            if (log.topics[0] === '0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef') {
                console.log('Transfer Event found:', {
                    from: '0x' + log.topics[1].slice(26),
                    to: '0x' + log.topics[2].slice(26),
                    value: BigInt(log.data),
                    contractAddress: log.address,
                    transactionHash: log.transactionHash
                })
            }
        })
        
    } catch (error) {
        console.error('Error details:', error)
    }
}

// 调用函数
watchTransferEvent2()


async function checkConnection() {
    try {
        // 检查链 ID
        const chainId = await publicClient.getChainId()
        console.log('Connected to chain ID:', chainId)
        
        // 获取当前区块高度
        const currentBlock = await publicClient.getBlockNumber()
        console.log('Current block:', currentBlock)
        
        // 获取区块信息
        const block = await publicClient.getBlock({ blockNumber: currentBlock })
        console.log('Block details:', {
            number: block.number,
            hash: block.hash,
            timestamp: block.timestamp,
            transactions: block.transactions.length
        })
        
        // 尝试获取账户余额
        const balance = await publicClient.getBalance({
            address: '0xdAC17F958D2ee523a2206206994597C13D831ec7'
        })
        console.log('Contract balance:', balance)
        
    } catch (error) {
        console.error('Error details:', error)
    }
}

// 调用函数
// checkConnection()


async function getChainIdHttp() {
    try {
        const response = await fetch('http://34.159.14.212:8545', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({
                jsonrpc: '2.0',
                method: 'eth_chainId',
                params: [],
                id: 1
            })
        })
        
        const data = await response.json()
        const chainId = parseInt(data.result, 16)  // 将十六进制转换为十进制
        console.log('Chain ID:', chainId)
    } catch (error) {
        console.error('Error:', error)
    }
}

// 调用函数
// getChainIdHttp()