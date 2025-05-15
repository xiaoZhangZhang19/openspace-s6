import { NextRequest, NextResponse } from 'next/server'
import mysql from 'mysql2/promise'

const dbConfig = {
    host: '127.0.0.1',
    user: 'root',
    password: '19981014',
    database: 'event'
}

const pool = mysql.createPool(dbConfig)

export async function GET(request: NextRequest) {
    try {
        const searchParams = request.nextUrl.searchParams
        const address = searchParams.get('address')
        const page = parseInt(searchParams.get('page') || '1')
        const limit = parseInt(searchParams.get('limit') || '20')
        const offset = (page - 1) * limit

        if (!address) {
            return NextResponse.json(
                { error: 'Address parameter is required' },
                { status: 400 }
            )
        }

        // 查询转账记录
        const [transfers] = await pool.execute(
            `SELECT 
                from_address,
                to_address,
                value,
                block_number,
                transaction_hash,
                contract_address,
                created_at
             FROM event.transfer_events 
             WHERE from_address = ? OR to_address = ?
             ORDER BY block_number DESC
             LIMIT ?, ?`,
            [address.toLowerCase(), address.toLowerCase(), String(offset), String(limit)]
        )

        // 获取总记录数
        const [countResult] = await pool.execute(
            `SELECT COUNT(*) as total
             FROM event.transfer_events 
             WHERE from_address = ? OR to_address = ?`,
            [address.toLowerCase(), address.toLowerCase()]
        ) as any

        const total = countResult[0].total

        return NextResponse.json({
            success: true,
            data: {
                transfers,
                pagination: {
                    page,
                    limit,
                    total,
                    totalPages: Math.ceil(total / limit)
                }
            }
        })

    } catch (error) {
        console.error('Error fetching transfers:', error)
        return NextResponse.json(
            { error: 'Internal server error', details: error instanceof Error ? error.message : String(error) },
            { status: 500 }
        )
    }
} 