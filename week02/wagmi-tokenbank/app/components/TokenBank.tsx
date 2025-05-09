'use client'

import { useState, useEffect } from 'react'
import { useWriteContract, useReadContract, useWaitForTransactionReceipt, useAccount } from 'wagmi'
import { parseEther, formatEther } from 'viem'
import TokenBankABI from '../contracts/abi/TokenBank.json'
import MyTokenABI from '../contracts/abi/MyTokenWithCallback.json'

export function TokenBank({ contractAddress, tokenAddress }: { contractAddress: string; tokenAddress: string }) {
  const [amount, setAmount] = useState('')
  const { address: userAddress } = useAccount()

  // 读取用户在Token中的余额
  const { data: tokenBalance, refetch: refetchTokenBalance } = useReadContract({
    address: tokenAddress as `0x${string}`,
    abi: MyTokenABI.abi,
    functionName: 'balanceOf',
    args: [userAddress],
  })

  // 读取用户在Bank中的存款余额
  const { data: bankBalance, refetch: refetchBankBalance } = useReadContract({
    address: contractAddress as `0x${string}`,
    abi: TokenBankABI.abi,
    functionName: 'tokenBalances',
    args: [userAddress],
  })

  // 检查Token授权额度
  const { data: allowance, refetch: refetchAllowance } = useReadContract({
    address: tokenAddress as `0x${string}`,
    abi: MyTokenABI.abi,
    functionName: 'allowance',
    args: [userAddress, contractAddress],
  })

  const { writeContract: writeToken } = useWriteContract()
  const { writeContract: writeBank, data: hash } = useWriteContract()
  const { isLoading: isProcessing, isSuccess } = useWaitForTransactionReceipt({ hash })

  // 交易成功后刷新余额
  useEffect(() => {
    if (isSuccess) {
      refetchTokenBalance()
      refetchBankBalance()
      refetchAllowance()
      setAmount('') // 清空输入框
    }
  }, [isSuccess, refetchTokenBalance, refetchBankBalance, refetchAllowance])

  const handleApprove = () => {
    if (!amount) return
    writeToken({
      address: tokenAddress as `0x${string}`,
      abi: MyTokenABI.abi,
      functionName: 'approve',
      args: [contractAddress, parseEther(amount)],
    })
  }

  const handleDeposit = () => {
    if (!amount) return
    writeBank({
      address: contractAddress as `0x${string}`,
      abi: TokenBankABI.abi,
      functionName: 'deposit',
      args: [parseEther(amount)],
    })
  }

  const handleWithdraw = () => {
    if (!amount) return
    writeBank({
      address: contractAddress as `0x${string}`,
      abi: TokenBankABI.abi,
      functionName: 'withdraw',
      args: [parseEther(amount)],
    })
  }

  // 检查是否需要授权
  const needsApproval = amount && allowance !== undefined && allowance !== null && 
    parseEther(amount) > (allowance as bigint)

  // 检查是否可以存款（余额充足）
  const canDeposit = amount && tokenBalance && parseEther(amount) <= (tokenBalance as bigint)

  // 检查是否可以取款（存款余额充足）
  const canWithdraw = amount && bankBalance && parseEther(amount) <= (bankBalance as bigint)

  const formattedTokenBalance = tokenBalance ? formatEther(tokenBalance as bigint) : '0'
  const formattedBankBalance = bankBalance ? formatEther(bankBalance as bigint) : '0'
  const formattedAllowance = allowance ? formatEther(allowance as bigint) : '0'

  return (
    <div className="p-4 space-y-4 border rounded-lg">
      <h2 className="text-2xl font-bold">Token Bank</h2>
      
      <div className="grid grid-cols-3 gap-4 p-4 bg-gray-50 rounded-lg">
        <div>
          <p className="text-sm text-gray-600">Your Token Balance:</p>
          <p className="text-lg font-semibold">
            {Number(formattedTokenBalance).toLocaleString()} TEST
          </p>
        </div>
        <div>
          <p className="text-sm text-gray-600">Your Bank Balance:</p>
          <p className="text-lg font-semibold">
            {Number(formattedBankBalance).toLocaleString()} TEST
          </p>
        </div>
        <div>
          <p className="text-sm text-gray-600">Approved Amount:</p>
          <p className="text-lg font-semibold">
            {Number(formattedAllowance).toLocaleString()} TEST
          </p>
        </div>
      </div>
      
      <div className="space-y-4">
        <div className="space-y-2">
          <label className="block text-sm font-medium text-gray-700">
            Amount (TEST)
          </label>
          <input
            type="number"
            placeholder="Enter amount in TEST"
            className="w-full p-2 border rounded"
            value={amount}
            onChange={(e) => setAmount(e.target.value)}
            min="0"
            step="0.000000000000000001"
          />
          {amount && needsApproval && (
            <p className="text-sm text-yellow-600">
              Additional approval of {(Number(amount) - Number(formattedAllowance)).toLocaleString()} TEST needed
            </p>
          )}
          {amount && !needsApproval && !canDeposit && (
            <p className="text-sm text-red-600">
              Insufficient token balance
            </p>
          )}
          {amount && !needsApproval && !canWithdraw && (
            <p className="text-sm text-red-600">
              Insufficient bank balance
            </p>
          )}
        </div>
        
        <div className="flex gap-2">
          {needsApproval ? (
            <button
              onClick={handleApprove}
              disabled={isProcessing || !amount}
              className="flex-1 p-2 bg-yellow-500 text-white rounded hover:bg-yellow-600 disabled:bg-gray-400"
            >
              {isProcessing ? 'Processing...' : 'Approve'}
            </button>
          ) : (
            <>
              <button
                onClick={handleDeposit}
                disabled={isProcessing || !amount || !canDeposit}
                className="flex-1 p-2 bg-green-500 text-white rounded hover:bg-green-600 disabled:bg-gray-400"
              >
                {isProcessing ? 'Processing...' : 'Deposit'}
              </button>
              
              <button
                onClick={handleWithdraw}
                disabled={isProcessing || !amount || !canWithdraw}
                className="flex-1 p-2 bg-red-500 text-white rounded hover:bg-red-600 disabled:bg-gray-400"
              >
                {isProcessing ? 'Processing...' : 'Withdraw'}
              </button>
            </>
          )}
        </div>

        {isSuccess && (
          <p className="text-sm text-green-500">
            Transaction successful!
          </p>
        )}
      </div>
    </div>
  )
} 