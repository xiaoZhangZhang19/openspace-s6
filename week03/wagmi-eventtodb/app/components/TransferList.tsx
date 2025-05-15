'use client'

import { useEffect, useState } from 'react'
import { useAccount } from 'wagmi'
import { getTransfersByAddress } from '../src/getTransfersByAddress'
import type { TransferEvent } from '../src/getTransfersByAddress'

export function TransferList() {
    const { address } = useAccount()
    const [transfers, setTransfers] = useState<TransferEvent[]>([])
    const [loading, setLoading] = useState(false)
    const [page, setPage] = useState(1)
    const [totalPages, setTotalPages] = useState(0)
    const [error, setError] = useState<string | null>(null)

    useEffect(() => {
        async function fetchTransfers() {
            if (!address) return;
            
            setLoading(true)
            setError(null)
            
            try {
                console.log('Fetching transfers for address:', address);
                const result = await getTransfersByAddress(address, page)
                console.log('Fetch result:', result);
                setTransfers(result.transfers)
                setTotalPages(result.pagination.totalPages)
            } catch (err) {
                console.error('Error fetching transfers:', err)
                setError(err instanceof Error ? err.message : '获取数据失败')
            } finally {
                setLoading(false)
            }
        }

        fetchTransfers()
    }, [address, page])

    if (!address) {
        return <div className="text-center mt-8">请先连接钱包</div>
    }

    if (loading) {
        return <div className="text-center mt-8">加载中...</div>
    }

    if (error) {
        return <div className="text-center mt-8 text-red-500">错误: {error}</div>
    }

    if (transfers.length === 0) {
        return (
            <div className="text-center mt-8">
                <p>暂无转账记录</p>
                <p className="text-sm text-gray-500 mt-2">当前查询地址: {address}</p>
            </div>
        )
    }

    return (
        <div className="container mx-auto px-4 py-8">
            <h2 className="text-2xl font-bold mb-6">转账记录</h2>
            <p className="text-sm text-gray-500 mb-4">当前查询地址: {address}</p>
            <div className="space-y-4">
                {transfers.map(transfer => (
                    <div 
                        key={transfer.transaction_hash}
                        className="bg-white shadow rounded-lg p-4"
                    >
                        <div className="grid grid-cols-2 gap-4">
                            <div>
                                <p className="text-sm text-gray-500">发送方</p>
                                <p className="text-sm font-mono break-all">{transfer.from_address}</p>
                            </div>
                            <div>
                                <p className="text-sm text-gray-500">接收方</p>
                                <p className="text-sm font-mono break-all">{transfer.to_address}</p>
                            </div>
                            <div>
                                <p className="text-sm text-gray-500">金额</p>
                                <p className="text-sm font-mono">{transfer.value}</p>
                            </div>
                            <div>
                                <p className="text-sm text-gray-500">区块</p>
                                <p className="text-sm font-mono">{transfer.block_number}</p>
                            </div>
                        </div>
                    </div>
                ))}
            </div>

            {totalPages > 1 && (
                <div className="flex justify-center gap-4 mt-6">
                    <button
                        onClick={() => setPage(p => Math.max(1, p - 1))}
                        disabled={page === 1}
                        className="px-4 py-2 bg-blue-500 text-white rounded disabled:bg-gray-300"
                    >
                        上一页
                    </button>
                    <span className="py-2">
                        第 {page} 页，共 {totalPages} 页
                    </span>
                    <button
                        onClick={() => setPage(p => p + 1)}
                        disabled={page >= totalPages}
                        className="px-4 py-2 bg-blue-500 text-white rounded disabled:bg-gray-300"
                    >
                        下一页
                    </button>
                </div>
            )}
        </div>
    )
} 