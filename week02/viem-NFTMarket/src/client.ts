import { createPublicClient, http, webSocket } from 'viem'
import { localhost, mainnet, sepolia } from 'viem/chains'
 
export const publicClient = createPublicClient({
  chain: localhost,
  transport: http("http://127.0.0.1:8545")
})

export const publicClient2 = createPublicClient({
  chain: {
    id: 80069,
    name: 'Custom Chain',
    network: 'custom',
    nativeCurrency: { name: 'Ether', symbol: 'ETH', decimals: 18 },
    rpcUrls: { 
      default: { 
        http: ['http://34.159.14.212:8545']
      } 
    }
  },
  transport: http('http://34.159.14.212:8545')
})