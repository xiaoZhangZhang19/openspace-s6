'use client'

import { CustomConnectButton } from './components/ConnectButton'
import { TokenBank } from './components/TokenBank'
import { useAccount, useChainId } from 'wagmi'

// 本地测试网络合约地址
const TOKEN_ADDRESS = '0x2279B7A0a67DB372996a5FaB50D91eAA73d2eBe6'
const BANK_ADDRESS = '0x8A791620dd6260079BF849Dc5567aDC3F2FdC318'

export default function Home() {
  const { isConnected } = useAccount()
  const chainId = useChainId()
  const isLocalNetwork = chainId === 31337

  return (
    <main className="min-h-screen p-8">
      <div className="max-w-2xl mx-auto space-y-8">
        <div className="flex flex-col gap-4 sm:flex-row sm:justify-between sm:items-center">
          <h1 className="text-3xl font-bold">Token Bank</h1>
          <CustomConnectButton />
        </div>

        {isConnected ? (
          isLocalNetwork ? (
            <div className="space-y-8">
              <TokenBank 
                contractAddress={BANK_ADDRESS} 
                tokenAddress={TOKEN_ADDRESS}
              />
            </div>
          ) : (
            <div className="text-center text-yellow-600 mt-8">
              Please connect to the Localhost network to interact with the contracts
            </div>
          )
        ) : (
          <div className="text-center text-gray-500 mt-8">
            Please connect your wallet to interact with the contracts
          </div>
        )}
      </div>
    </main>
  )
}
