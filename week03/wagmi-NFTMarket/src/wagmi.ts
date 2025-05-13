import { getDefaultConfig } from '@rainbow-me/rainbowkit'
import { mainnet, sepolia } from 'wagmi/chains'
import { http } from 'viem'

export const config = getDefaultConfig({
  appName: 'NFT Market',
  projectId: 'edbd8bada7f34d2682d03a42de4fe62f', // Get one from https://cloud.walletconnect.com
  chains: [mainnet, sepolia],
  transports: {
    [mainnet.id]: http("https://eth-mainnet.g.alchemy.com/v2/xzt2Sc3zEv1uZig0bdIH5KvYak7rb3Pi"),
    [sepolia.id]: http("https://eth-sepolia.g.alchemy.com/v2/xzt2Sc3zEv1uZig0bdIH5KvYak7rb3Pi"),
  },
}) 