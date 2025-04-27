'use client'

import { 
  useAccount, 
  useConnect, 
  useDisconnect,
  useBalance,
  useSwitchChain} from 'wagmi'

import { ConnectButton } from '@rainbow-me/rainbowkit'
import { useState, useEffect} from 'react'
import { Address } from 'viem'
import { useQueryErrorResetBoundary } from '@tanstack/react-query'
import { SendETHButton } from './components/SentETH'
import {TokenButton} from "./components/MintToken"

function App() {
  const account = useAccount()
  const [userAddress, setUserAddress] = useState("");
  const { connectors, connect, status, error } = useConnect()
  const { disconnect } = useDisconnect()

  const {chains, switchChain} = useSwitchChain()
  const {data:userBalance} = useBalance({
    address: userAddress as Address
  })

  useEffect(()=>{
    if(account && account.address){
      setUserAddress(account.address);
    }
    else{
      setUserAddress("");
    }
  },[account])

  return (
    <>
      <div>
        <h2>Account</h2>

        <div>
          status: {account.status}
          <br />
          addresses: {JSON.stringify(account.addresses)}
          <br />
          chainId: {account.chainId}
          <br/>
          balance: {userBalance?.formatted}
          {userBalance?.symbol}
        </div>

        {account.status === 'connected' && (
          <button type="button" onClick={() => disconnect()}>
            Disconnect
          </button>
        )}
      </div>
      <div>
        <ConnectButton></ConnectButton>
      </div>
      <div>
        {chains.map((chain)=>(<button key={chain.id} onClick={()=>
        switchChain({chainId: chain.id})
      }>
        {chain.name}
        </button>)
      )}
      </div>

      <hr>
      </hr>
        <SendETHButton></SendETHButton>
      <div>
        <h2>Connect</h2>
        {connectors.map((connector) => (
          <button 
            style={{
            backgroundColor: "blue",
            color: "white",
            padding: "12px 24px",
            borderRadius: "8px",
            border: "none",
            cursor: "pointer"
          }}
            key={connector.uid}
            onClick={() => connect({ connector })}
            type="button"
          >
            {connector.name}
          </button>
        ))}
        <div>{status}</div>
        <div>{error?.message}</div>
      </div>
      <hr />
        <TokenButton></TokenButton>
    </>
  )
}

export default App
