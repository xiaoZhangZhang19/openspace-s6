'use client'

import { useAccount, useChainId } from 'wagmi'

export function NetworkSwitcher() {
  const { connector } = useAccount()
  const chainId = useChainId()

  const localChain = {
    id: 31337,
    name: 'Localhost',
    network: 'localhost',
    nativeCurrency: {
      decimals: 18,
      name: 'Ethereum',
      symbol: 'ETH',
    },
    rpcUrls: {
      default: { http: ['http://localhost:8545'] },
      public: { http: ['http://localhost:8545'] },
    }
  }

  const switchToLocal = async () => {
    try {
      if (!connector) return
      // 先尝试添加本地网络
      try {
        await window.ethereum?.request({
          method: 'wallet_addEthereumChain',
          params: [
            {
              chainId: '0x' + (31337).toString(16),
              chainName: 'Localhost',
              nativeCurrency: {
                name: 'Ethereum',
                symbol: 'ETH',
                decimals: 18
              },
              rpcUrls: ['http://localhost:8545']
            }
          ]
        })
      } catch (addError) {
        console.log('Network might already exist:', addError)
      }

      // 然后切换到本地网络
      await window.ethereum?.request({
        method: 'wallet_switchEthereumChain',
        params: [{ chainId: '0x' + (31337).toString(16) }]
      })
    } catch (error) {
      console.error('Failed to switch network:', error)
    }
  }

  const isLocalNetwork = chainId === 31337

  return (
    <button
      onClick={switchToLocal}
      className={`px-4 py-2 text-sm font-medium text-white rounded-md 
        ${isLocalNetwork 
          ? 'bg-green-600 hover:bg-green-700' 
          : 'bg-yellow-500 hover:bg-yellow-600'
        }`}
    >
      {isLocalNetwork ? '✓ Connected to Localhost' : 'Switch to Localhost'}
    </button>
  )
} 