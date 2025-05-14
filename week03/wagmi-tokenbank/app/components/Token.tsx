'use client'

import { useState } from 'react'
import { useWriteContract, useReadContract, useWaitForTransactionReceipt } from 'wagmi'
import { parseEther } from 'viem'
import MyTokenABI from '../contracts/abi/MyTokenWithCallback.json'

export function Token({ contractAddress }: { contractAddress: string }) {
  const [amount, setAmount] = useState('')
  const [recipient, setRecipient] = useState('')

  const { data: balance } = useReadContract({
    address: contractAddress as `0x${string}`,
    abi: MyTokenABI.abi,
    functionName: 'balanceOf',
    args: [recipient],
    enabled: !!recipient,
  })

  const { writeContract, data: hash } = useWriteContract()
  const { isLoading: isTransferring, isSuccess } = useWaitForTransactionReceipt({ hash })

  const handleTransfer = () => {
    if (!amount || !recipient) return
    writeContract({
      address: contractAddress as `0x${string}`,
      abi: MyTokenABI.abi,
      functionName: 'transfer',
      args: [recipient, parseEther(amount)],
    })
  }

  return (
    <div className="p-4 space-y-4">
      <h2 className="text-2xl font-bold">Token Operations</h2>
      
      <div className="space-y-2">
        <input
          type="text"
          placeholder="Recipient Address"
          className="w-full p-2 border rounded"
          value={recipient}
          onChange={(e) => setRecipient(e.target.value)}
        />
        
        <input
          type="number"
          placeholder="Amount"
          className="w-full p-2 border rounded"
          value={amount}
          onChange={(e) => setAmount(e.target.value)}
        />
        
        <button
          onClick={handleTransfer}
          disabled={isTransferring}
          className="w-full p-2 bg-blue-500 text-white rounded hover:bg-blue-600 disabled:bg-gray-400"
        >
          {isTransferring ? 'Transferring...' : 'Transfer'}
        </button>

        {balance && (
          <p className="text-sm">
            Balance: {balance.toString()} wei
          </p>
        )}

        {isSuccess && (
          <p className="text-sm text-green-500">
            Transfer successful!
          </p>
        )}
      </div>
    </div>
  )
} 