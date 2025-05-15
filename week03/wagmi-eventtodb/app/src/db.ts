import mysql from 'mysql2/promise'

// 数据库配置
const dbConfig = {
    host: '127.0.0.1',
    user: 'root',
    password: '19981014',
    database: 'event'
}

// 创建连接池
const pool = mysql.createPool(dbConfig)

// 初始化数据库表
export async function initDatabase() {
    try {
        const connection = await pool.getConnection()
        
        // 创建数据库（如果不存在）
        await connection.query(`CREATE DATABASE IF NOT EXISTS ${dbConfig.database}`)
        await connection.query(`USE ${dbConfig.database}`)
        
        // 创建转账事件表
        await connection.query(`
            CREATE TABLE IF NOT EXISTS event.transfer_events (
                id BIGINT AUTO_INCREMENT PRIMARY KEY,
                from_address VARCHAR(42) NOT NULL,
                to_address VARCHAR(42) NOT NULL,
                value VARCHAR(78) NOT NULL,
                block_number BIGINT NOT NULL,
                transaction_hash VARCHAR(66) NOT NULL,
                contract_address VARCHAR(42) NOT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                UNIQUE KEY unique_transfer (transaction_hash, from_address, to_address)
            )
        `)
        
        connection.release()
        console.log('Database initialized successfully')
    } catch (error) {
        console.error('Error initializing database:', error)
        throw error
    }
}

// 插入转账事件
export async function insertTransferEvent(event: {
    from: string
    to: string
    value: string
    blockNumber: bigint
    transactionHash: string
    contractAddress: string
}) {
    try {
        const [result] = await pool.execute(
            `INSERT INTO event.transfer_events (from_address, to_address, value, block_number, transaction_hash, contract_address)
             VALUES (?, ?, ?, ?, ?, ?)`,
            [
                event.from,
                event.to,
                event.value,
                event.blockNumber.toString(),
                event.transactionHash,
                event.contractAddress
            ]
        )
        return result
    } catch (error) {
        // 如果是重复记录，我们就忽略它
        if ((error as any).code === 'ER_DUP_ENTRY') {
            console.log('Duplicate event, skipping...')
            return null
        }
        throw error
    }
}

export default pool 