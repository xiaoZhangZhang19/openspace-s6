import { publicClient3 } from './client'
import { keccak256 } from 'viem'

// 合约地址
const contractAddress = '0x6C95F49e72C1Ad49A54652904448e0646640657d' as `0x${string}`

// 读取数组长度
async function getArrayLength() {
  const length = await publicClient3.getStorageAt({
    address: contractAddress,
    slot: '0x0'
  })
  return Number(length || 0)
}

// 读取单个 LockInfo
async function getLockInfo(index: number) {
  // 计算数组元素的起始位置
  const arraySlot = BigInt(keccak256('0x0000000000000000000000000000000000000000000000000000000000000000'))
  const elementSlot = arraySlot + BigInt(index * 2) // 每个元素占用2个槽（user+startTime打包，amount单独）

  // 读取两个槽
  const [packedSlot, amountSlot] = await Promise.all([
    publicClient3.getStorageAt({
      address: contractAddress,
      // getStorageAt 的 slot 参数需要是十六进制字符串, 所以需要转换
      slot: `0x${elementSlot.toString(16)}`
    }),
    publicClient3.getStorageAt({
      address: contractAddress,
      // getStorageAt 的 slot 参数需要是十六进制字符串, 所以需要转换
      slot: `0x${(elementSlot + 1n).toString(16)}`
    })
  ])

  // 解析数据, 将两个槽的数据合并
  const packed = BigInt(packedSlot || 0)
  // 在 Solidity 中，address 在低 20 字节，uint64 在高 8 字节
  const user = `0x${(packed & ((1n << 160n) - 1n)).toString(16).padStart(40, '0')}` // 取低20字节作为地址
  const startTime = Number((packed >> 160n) & ((1n << 64n) - 1n)) // 取高8字节作为时间
  const amount = BigInt(amountSlot || 0)

  return {
    user,
    startTime,
    amount
  }
}

// 主函数
async function main() {
  const length = await getArrayLength()
  console.log(`Total locks: ${length}`)

  for (let i = 0; i < length; i++) {
    const lock = await getLockInfo(i)
    console.log(`_locks[${i}]: user: ${lock.user}, startTime: ${lock.startTime}, amount: ${lock.amount}`)
  }
}

main().catch(console.error) 