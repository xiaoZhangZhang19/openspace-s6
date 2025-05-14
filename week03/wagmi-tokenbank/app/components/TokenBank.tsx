'use client'

import { useState, useEffect } from 'react'
import { useWriteContract, useReadContract, useWaitForTransactionReceipt, useAccount, useSignTypedData, useChainId } from 'wagmi'
import { parseEther, formatEther } from 'viem'
import TokenBank2ABI from '../contracts/abi/TokenBank2.json'
import MyTokenABI from '../contracts/abi/MyTokenWithCallback.json'

export function TokenBank({ contractAddress, tokenAddress }: { contractAddress: string; tokenAddress: string }) {
  const [amount, setAmount] = useState('')
  const { address: userAddress } = useAccount()
  const [isSignatureProcessing, setIsSignatureProcessing] = useState(false)
  const chainId = useChainId()

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
    abi: TokenBank2ABI.abi,
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

  // 获取nonce值
  const { data: nonce, refetch: refetchNonce } = useReadContract({
    address: tokenAddress as `0x${string}`,
    abi: MyTokenABI.abi,
    functionName: 'nonces',
    args: [userAddress],
  })

  const { writeContract: writeToken, data: tokenHash } = useWriteContract()
  const { writeContract: writeBank, data: bankHash } = useWriteContract()
  const { isLoading: isTokenProcessing, isSuccess: isTokenSuccess } = useWaitForTransactionReceipt({ hash: tokenHash })
  const { isLoading: isBankProcessing, isSuccess: isBankSuccess } = useWaitForTransactionReceipt({ hash: bankHash })

  // 签名相关
  const { signTypedData, signTypedDataAsync } = useSignTypedData()

  const isProcessing = isTokenProcessing || isBankProcessing || isSignatureProcessing
  const isSuccess = isTokenSuccess || isBankSuccess

  // 交易成功后刷新余额
  useEffect(() => {
    if (isTokenSuccess || isBankSuccess) {
      refetchTokenBalance()
      refetchBankBalance()
      refetchAllowance()
      refetchNonce()
      setAmount('') // 清空输入框
    }
  }, [isTokenSuccess, isBankSuccess, refetchTokenBalance, refetchBankBalance, refetchAllowance, refetchNonce])

  // 添加自动刷新逻辑
  useEffect(() => {
    const interval = setInterval(() => {
      if (isProcessing) {
        refetchTokenBalance()
        refetchBankBalance()
        refetchAllowance()
        refetchNonce()
      }
    }, 3000) // 每3秒刷新一次

    return () => clearInterval(interval)
  }, [isProcessing, refetchTokenBalance, refetchBankBalance, refetchAllowance, refetchNonce])

  // 处理授权
  const handleApprove = () => {
    if (!amount) return
    writeToken({
      address: tokenAddress as `0x${string}`,
      abi: MyTokenABI.abi,
      functionName: 'approve',
      args: [contractAddress, parseEther(amount)],
    })
  }

  // 处理存款
  const handleDeposit = () => {
    if (!amount) return
    writeBank({
      address: contractAddress as `0x${string}`,
      abi: TokenBank2ABI.abi,
      functionName: 'deposit',
      args: [parseEther(amount)],
    })
  }

  // 处理提款
  const handleWithdraw = () => {
    if (!amount) return
    writeBank({
      address: contractAddress as `0x${string}`,
      abi: TokenBank2ABI.abi,
      functionName: 'withdraw',
      args: [parseEther(amount)],
    })
  }

  // 处理直接存款
  const handleDirectDeposit = () => {
    if (!amount) return
    console.log('handleDirectDeposit', amount)
    writeToken({
      address: tokenAddress as `0x${string}`,
      abi: MyTokenABI.abi,
      functionName: 'transferWithCallback',
      args: [contractAddress, parseEther(amount)],
    })
  }

  // 处理签名存款
  const handleSignatureDeposit = async () => {
    if (!amount || !userAddress) return
    setIsSignatureProcessing(true)

    try {
      // 检查nonce是否已获取
      if (nonce === undefined) {
        console.error('Nonce is undefined')
        throw new Error('Nonce not available')
      }

      // 检查合约地址
      if (!contractAddress || !tokenAddress) {
        console.error('Contract addresses missing:', { contractAddress, tokenAddress })
        throw new Error('Contract addresses not available')
      }

      const value = parseEther(amount)
      const deadline = BigInt(Math.floor(Date.now() / 1000) + 3600) // 1小时后过期

      const domain = {
        name: 'Test Token',
        version: '1',
        chainId,
        verifyingContract: tokenAddress as `0x${string}`,
      }

      const types = {
        Permit: [
          { name: 'owner', type: 'address' },
          { name: 'spender', type: 'address' },
          { name: 'value', type: 'uint256' },
          { name: 'nonce', type: 'uint256' },
          { name: 'deadline', type: 'uint256' },
        ],
      }

      const message = {
        owner: userAddress,
        spender: contractAddress,
        value, // 使用精确的金额
        nonce,
        deadline,
      }

      console.log('Preparing to sign with:', {
        domain,
        types,
        message: {
          ...message,
          value: value.toString(),
          nonce: nonce?.toString() ?? 'undefined',
          deadline: deadline.toString(),
        },
      })

      // 获取签名
      const signatureResult = await signTypedDataAsync({
        domain,
        types,
        primaryType: 'Permit',
        message,
      })

      if (!signatureResult) {
        console.error('No signature result')
        throw new Error('Failed to get signature')
      }

      // Split signature into r, s, v components
      const signature = signatureResult as `0x${string}`
      const r = '0x' + signature.slice(2, 66)
      const s = '0x' + signature.slice(66, 130)
      const v = parseInt(signature.slice(130, 132), 16)

      console.log('Signature components:', { r, s, v })

      // 调用合约的permitDeposit方法
      writeBank({
        address: contractAddress as `0x${string}`,
        abi: TokenBank2ABI.abi,
        functionName: 'permitDeposit',
        args: [
          value,
          deadline,
          v,
          r,
          s,
        ],
      })

    } catch (error) {
      console.error('Signature deposit error:', error)
      throw error
    } finally {
      setIsSignatureProcessing(false)
    }
  }

  // 检查是否需要授权
  const needsApproval = amount && allowance !== undefined && allowance !== null && 
    parseEther(amount) > (allowance as bigint)

  // 检查是否可以存款（余额充足）
  const canDeposit = amount && tokenBalance && parseEther(amount) <= (tokenBalance as bigint)

  // 检查是否可以取款（存款余额充足）
  const canWithdraw = amount && bankBalance !== undefined && bankBalance !== null && 
    parseEther(amount) <= (bankBalance as bigint)

  const formattedTokenBalance = tokenBalance ? formatEther(tokenBalance as bigint) : '0'
  const formattedBankBalance = bankBalance ? formatEther(bankBalance as bigint) : '0'
  const formattedAllowance = allowance ? formatEther(allowance as bigint) : '0'

  // 添加调试信息
  console.log('Debug Info:', {
    userAddress,
    tokenAddress,
    contractAddress,
    rawTokenBalance: tokenBalance?.toString(),
    formattedTokenBalance,
    rawBankBalance: bankBalance?.toString(),
    formattedBankBalance
  })

  return (
    <div className="p-4 space-y-4 border rounded-lg">
      <h2 className="text-2xl font-bold">Token Bank</h2>
      
      <div className="grid grid-cols-3 gap-4 p-4 bg-gray-50 rounded-lg">
        <div>
          <p className="text-sm text-gray-600">Your Token Balance:</p>
          <p className="text-lg font-semibold">
            {formattedTokenBalance} TEST
          </p>
          <p className="text-xs text-gray-500">Raw: {tokenBalance?.toString() || '0'}</p>
        </div>
        <div>
          <p className="text-sm text-gray-600">Your Bank Balance:</p>
          <p className="text-lg font-semibold">
            {formattedBankBalance} TEST
          </p>
          <p className="text-xs text-gray-500">Raw: {bankBalance?.toString() || '0'}</p>
        </div>
        <div>
          <p className="text-sm text-gray-600">Approved Amount:</p>
          <p className="text-lg font-semibold">
            {formattedAllowance} TEST
          </p>
          <p className="text-xs text-gray-500">Raw: {allowance?.toString() || '0'}</p>
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
          {amount && !canDeposit && (
            <p className="text-sm text-red-600">
              Insufficient token balance for deposit
            </p>
          )}
          {amount && !canWithdraw && bankBalance !== undefined && parseEther(amount) > (bankBalance as bigint) && (
            <p className="text-sm text-red-600">
              Insufficient bank balance for withdrawal
            </p>
          )}
        </div>
        
        <div className="flex gap-2">
          {needsApproval ? (
            <>
              <button
                onClick={handleApprove}
                disabled={isProcessing || !amount}
                className="flex-1 p-2 bg-yellow-500 text-white rounded hover:bg-yellow-600 disabled:bg-gray-400"
              >
                {isProcessing ? 'Processing...' : 'Approve'}
              </button>
              
              <button
                onClick={handleSignatureDeposit}
                disabled={isProcessing || !amount || !canDeposit}
                className="flex-1 p-2 bg-purple-500 text-white rounded hover:bg-purple-600 disabled:bg-gray-400"
              >
                {isProcessing ? 'Processing...' : 'Deposit (Signature)'}
              </button>

              <button
                onClick={handleDirectDeposit}
                disabled={isProcessing || !amount || !canDeposit}
                className="flex-1 p-2 bg-blue-500 text-white rounded hover:bg-blue-600 disabled:bg-gray-400"
              >
                {isProcessing ? 'Processing...' : 'Deposit (Direct)'}
              </button>

              <button
                onClick={handleWithdraw}
                disabled={isProcessing || !amount || !canWithdraw}
                className="flex-1 p-2 bg-red-500 text-white rounded hover:bg-red-600 disabled:bg-gray-400"
              >
                {isProcessing ? 'Processing...' : 'Withdraw'}
              </button>
            </>
          ) : (
            <>
              <button
                onClick={handleDeposit}
                disabled={isProcessing || !amount || !canDeposit}
                className="flex-1 p-2 bg-green-500 text-white rounded hover:bg-green-600 disabled:bg-gray-400"
              >
                {isProcessing ? 'Processing...' : 'Deposit (Standard)'}
              </button>

              <button
                onClick={handleSignatureDeposit}
                disabled={isProcessing || !amount || !canDeposit}
                className="flex-1 p-2 bg-purple-500 text-white rounded hover:bg-purple-600 disabled:bg-gray-400"
              >
                {isProcessing ? 'Processing...' : 'Deposit (Signature)'}
              </button>

              <button
                onClick={handleDirectDeposit}
                disabled={isProcessing || !amount || !canDeposit}
                className="flex-1 p-2 bg-blue-500 text-white rounded hover:bg-blue-600 disabled:bg-gray-400"
              >
                {isProcessing ? 'Processing...' : 'Deposit (Direct)'}
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