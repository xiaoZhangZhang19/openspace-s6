import { ConnectButton } from './components/ConnectButton'
import { TransferList } from './components/TransferList'

export default function Home() {
  return (
    <main className="flex min-h-screen flex-col items-center p-24">
      <ConnectButton />
      <TransferList />
    </main>
  )
}
