import { getDefaultConfig } from '@rainbow-me/rainbowkit'
import { mainnet, sepolia, Chain } from 'wagmi/chains'
import { http } from 'wagmi'

const localhost: Chain = {
  id: 31337,
  name: 'Localhost',
  nativeCurrency: {
    decimals: 18,
    name: 'Ethereum',
    symbol: 'ETH',
  },
  rpcUrls: {
    default: { http: ['http://127.0.0.1:8545'] },
    public: { http: ['http://127.0.0.1:8545'] },
  }
}

export const config = getDefaultConfig({
  appName: 'RainbowKit Demo',
  projectId: 'edbd8bada7f34d2682d03a42de4fe62f', // Get one from https://cloud.walletconnect.com
  chains: [mainnet, sepolia, localhost],
  transports: {
    [mainnet.id]: http(),
    [sepolia.id]: http(),
    [localhost.id]: http(),
  },
}) 