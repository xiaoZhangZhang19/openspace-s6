'use client'

import { CustomConnectButton } from './components/ConnectButton'
import { TokenBank } from './components/TokenBank'
import { useAccount, useChainId } from 'wagmi'

// 本地测试网络合约地址
const TOKEN_ADDRESS = '0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9'
const BANK_ADDRESS = '0xDc64a140Aa3E981100a9becA4E685f962f0cF6C9'

export default function Home() {
  const { isConnected } = useAccount()
  const chainId = useChainId()
  const isLocalNetwork = chainId === 31337

  return (
    <main className="min-h-screen p-8">
      <div className="max-w-2xl mx-auto space-y-8">
        <div className="flex flex-col gap-4 sm:flex-row sm:justify-between sm:items-center">
          <h1 className="text-3xl font-bold">Token Bank Demo</h1>
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
