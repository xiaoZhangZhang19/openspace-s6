import { createPublicClient, http, webSocket } from 'viem'
import { localhost, mainnet, sepolia } from 'viem/chains'
 
export const publicClient = createPublicClient({
  chain: localhost,
  transport: http("http://127.0.0.1:8545")
})

export const publicClient2 = createPublicClient({
  chain: sepolia,
  transport: http("https://eth-sepolia.g.alchemy.com/v2/xzt2Sc3zEv1uZig0bdIH5KvYak7rb3Pi")
})