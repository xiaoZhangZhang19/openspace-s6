//0x67C16fDb5A44042c79eFB0f033EeDeD76375677C sepolia

import { publicClient2 } from './client.js'
import { parseAbiItem } from 'viem/utils'
import { initDatabase, insertTransferEvent } from './db.js'

const CONTRACT_ADDRESS = '0x67C16fDb5A44042c79eFB0f033EeDeD76375677C'

async function getERC20EventToMysql() {
    try {
        // 初始化数据库
        await initDatabase()
        console.log('Database initialized')

        // 获取当前区块高度
        const currentBlock = await publicClient2.getBlockNumber()
        console.log('Current block:', currentBlock)
        
        // 设置查询范围为最近的 2000 个区块，但分批查询
        const totalBlocksToSearch = 2000n
        const batchSize = 400n // 使用400而不是500，留一些余量
        const startBlock = currentBlock - totalBlocksToSearch
        
        console.log('Will search from block', startBlock, 'to', currentBlock)
        
        let allLogs: any[] = []
        let savedCount = 0
        
        // 分批获取日志
        for (let fromBlock = startBlock; fromBlock < currentBlock; fromBlock += batchSize) {
            const toBlock = fromBlock + batchSize > currentBlock ? currentBlock : fromBlock + batchSize
            console.log(`Searching batch from ${fromBlock} to ${toBlock}...`)
            
            const logs = await publicClient2.getLogs({
                address: CONTRACT_ADDRESS,
                event: parseAbiItem('event Transfer(address indexed from, address indexed to, uint256 value)'),
                fromBlock: fromBlock,
                toBlock: toBlock
            })
            
            // 保存每个事件到数据库
            for (const log of logs) {
                try {
                    if (log.args.from && log.args.to) {
                        await insertTransferEvent({
                            from: log.args.from,
                            to: log.args.to,
                            value: log.args.value?.toString() || '0',
                            blockNumber: log.blockNumber,
                            transactionHash: log.transactionHash,
                            contractAddress: CONTRACT_ADDRESS
                        })
                        savedCount++
                    }
                } catch (error) {
                    console.error('Error saving event:', error)
                }
            }
            
            allLogs = allLogs.concat(logs)
        }
        
        if (allLogs.length === 0) {
            console.log('No events found in the specified block range')
        } else {
            console.log('Found', allLogs.length, 'events')
            console.log('Successfully saved', savedCount, 'events to database')
        }
    } catch (error) {
        console.error('Error fetching events:', error)
    }
}

// 运行程序
getERC20EventToMysql()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error('Fatal error:', error)
        process.exit(1)
    })
