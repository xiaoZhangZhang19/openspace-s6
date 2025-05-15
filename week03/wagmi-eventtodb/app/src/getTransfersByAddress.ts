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

export interface TransferEvent {
    from_address: string;
    to_address: string;
    value: string;
    block_number: string;
    transaction_hash: string;
    contract_address: string;
    created_at: Date;
}

interface PaginatedResult {
    transfers: TransferEvent[];
    pagination: {
        page: number;
        limit: number;
        total: number;
        totalPages: number;
    }
}

export async function getTransfersByAddress(
    address: string,
    page: number = 1,
    limit: number = 20
): Promise<PaginatedResult> {
    try {
        console.log('开始获取转账记录，参数：', { address, page, limit });
        
        const url = `/api/transfers?address=${encodeURIComponent(address)}&page=${page}&limit=${limit}`;
        console.log('请求 URL:', url);
        
        const response = await fetch(url);
        console.log('API 响应状态:', response.status);
        
        if (!response.ok) {
            const errorText = await response.text();
            console.error('API 错误响应:', errorText);
            throw new Error(`请求失败: ${response.status} ${response.statusText}`);
        }

        const data = await response.json();
        console.log('API 响应数据:', data);
        
        if (!data.success) {
            throw new Error(data.error || '获取转账记录失败');
        }

        return {
            transfers: data.data.transfers,
            pagination: data.data.pagination
        };
    } catch (error) {
        console.error('获取转账记录时出错:', error);
        throw error;
    }
}

// 使用示例：
/*
import { useAccount } from 'wagmi'
import { getTransfersByAddress } from './getTransfersByAddress'

// 在React组件中：
const YourComponent = () => {
    const { address } = useAccount()
    const [transfers, setTransfers] = useState<TransferEvent[]>([])
    const [page, setPage] = useState(1)
    const [loading, setLoading] = useState(false)

    useEffect(() => {
        if (address) {
            setLoading(true)
            getTransfersByAddress(address, page)
                .then(result => {
                    setTransfers(result.transfers)
                })
                .catch(console.error)
                .finally(() => setLoading(false))
        }
    }, [address, page])

    return (
        <div>
            {transfers.map(transfer => (
                <div key={transfer.transaction_hash}>
                    <p>From: {transfer.from_address}</p>
                    <p>To: {transfer.to_address}</p>
                    <p>Value: {transfer.value}</p>
                    <p>Block: {transfer.block_number}</p>
                </div>
            ))}
        </div>
    )
}
*/ 