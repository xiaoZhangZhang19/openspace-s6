import { createPublicClient, http } from 'viem'
import { localhost, mainnet } from 'viem/chains'
 
export const publicClient = createPublicClient({
  chain: localhost,
  transport: http("http://127.0.01:8545")
})