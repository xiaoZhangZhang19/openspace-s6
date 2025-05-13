import { useState, useEffect, useCallback } from 'react'
import { useAccount, useContractRead, useWriteContract, usePublicClient } from 'wagmi'
import { CONTRACT_ADDRESS } from '../config/contracts'
import { MarketNFTABI } from '../ABI/MarketNFTABI'
import { MarketTokenABI } from '../ABI/MarketTokenABI'
import { NFTMarketABI } from '../ABI/NFTMarketABI'
import { parseEther } from 'viem'
import './NFTMarket.css'

export function NFTMarket() {
  const { address } = useAccount()
  const publicClient = usePublicClient()
  const [listingNFTId, setListingNFTId] = useState('')
  const [buyingNFTId, setBuyingNFTId] = useState('')
  const [listingPrice, setListingPrice] = useState('')
  const [buyingPrice, setBuyingPrice] = useState('')
  const [isApproving, setIsApproving] = useState(false)
  const [isListing, setIsListing] = useState(false)
  const [isBuying, setIsBuying] = useState(false)
  const [isApprovingToken, setIsApprovingToken] = useState(false)
  const [marketNFTs, setMarketNFTs] = useState<number[]>([])
  const [userNFTs, setUserNFTs] = useState<number[]>([])
  const [isLoading, setIsLoading] = useState(false)
  const [isRefreshing, setIsRefreshing] = useState(false)

  // NFT 授权
  const { writeContract: approveNFT } = useWriteContract()

  // Token 授权
  const { writeContract: approveToken } = useWriteContract()

  // 读取 NFT 总供应量
  const { data: totalSupply } = useContractRead({
    address: CONTRACT_ADDRESS.MARKET_NFT,
    abi: MarketNFTABI,
    functionName: 'totalSupply',
  })

  // 获取 NFT 列表
  const fetchNFTLists = useCallback(async () => {
    if (!totalSupply || !address || !publicClient) return
    
    setIsLoading(true)
    setIsRefreshing(true)
    try {
      const total = Number(totalSupply)
      const marketNFTList: number[] = []
      const userNFTList: number[] = []

      // 遍历所有 NFT
      for (let i = 1; i <= total; i++) {
        const owner = await publicClient.readContract({
          address: CONTRACT_ADDRESS.MARKET_NFT,
          abi: MarketNFTABI,
          functionName: 'ownerOf',
          args: [BigInt(i)]
        })

        if (owner === CONTRACT_ADDRESS.NFT_MARKET) {
          marketNFTList.push(i)
        } else if (owner === address) {
          userNFTList.push(i)
        }
      }

      setMarketNFTs(marketNFTList)
      setUserNFTs(userNFTList)
    } catch (error) {
      console.error('Error fetching NFT lists:', error)
    }
    setIsLoading(false)
    setIsRefreshing(false)
  }, [totalSupply, address, publicClient])

  // 当地址或总供应量变化时更新列表
  useEffect(() => {
    fetchNFTLists()
  }, [fetchNFTLists])

  // NFT授权
  const handleApproveNFT = async () => {
    if (!listingNFTId) return
    try {
      setIsApproving(true)
      await approveNFT({
        address: CONTRACT_ADDRESS.MARKET_NFT,
        abi: MarketNFTABI,
        functionName: 'approve',
        args: [CONTRACT_ADDRESS.NFT_MARKET, BigInt(listingNFTId)]
      })
      setIsApproving(false)
    } catch (error) {
      console.error('Error approving NFT:', error)
      setIsApproving(false)
    }
  }

  // NFT上架
  const handleList = async () => {
    if (!listingNFTId || !listingPrice) return
    try {
      setIsListing(true)
      await approveNFT({
        address: CONTRACT_ADDRESS.NFT_MARKET,
        abi: NFTMarketABI,
        functionName: 'list',
        args: [
          CONTRACT_ADDRESS.MARKET_NFT,    // NFT 合约地址
          BigInt(listingNFTId),          // NFT ID
          CONTRACT_ADDRESS.MARKET_TOKEN,  // 代币合约地址
          parseEther(listingPrice)       // 上架价格
        ]
      })
      setIsListing(false)
      // 清空输入
      setListingNFTId('')
      setListingPrice('')
      // 刷新列表
      await fetchNFTLists()
    } catch (error) {
      console.error('Error listing NFT:', error)
      setIsListing(false)
    }
  }

  // 代币授权
  const handleApproveToken = async () => {
    if (!buyingPrice) return
    try {
      setIsApprovingToken(true)
      await approveToken({
        address: CONTRACT_ADDRESS.MARKET_TOKEN,
        abi: MarketTokenABI,
        functionName: 'approve',
        args: [CONTRACT_ADDRESS.NFT_MARKET, parseEther(buyingPrice)]
      })
      setIsApprovingToken(false)
    } catch (error) {
      console.error('Error approving token:', error)
      setIsApprovingToken(false)
    }
  }

  // 购买NFT
  const handleBuy = async () => {
    if (!buyingNFTId) return
    try {
      setIsBuying(true)
      await approveToken({
        address: CONTRACT_ADDRESS.NFT_MARKET,
        abi: NFTMarketABI,
        functionName: 'buyNFT',
        args: [CONTRACT_ADDRESS.MARKET_NFT, CONTRACT_ADDRESS.MARKET_TOKEN, BigInt(buyingNFTId)]
      })
      setIsBuying(false)
      // 清空输入
      setBuyingNFTId('')
      setBuyingPrice('')
      // 刷新列表
      await fetchNFTLists()
    } catch (error) {
      console.error('Error buying NFT:', error)
      setIsBuying(false)
    }
  }

  return (
    <div className="nft-market">
      <div className="wallet-connect">
      </div>
      
      <div className="market-sections">
        <div className="left-section">
          <div className="approve-nft">
            <h3>Approve NFT</h3>
            <input
              type="text"
              placeholder="NFT Token ID"
              value={listingNFTId}
              onChange={(e) => setListingNFTId(e.target.value)}
            />
            <button onClick={handleApproveNFT} disabled={isApproving}>
              {isApproving ? 'Approving NFT...' : 'Approve NFT'}
            </button>
          </div>

          <div className="list-nft">
            <h3>List NFT</h3>
            <input
              type="text"
              placeholder="NFT Token ID"
              value={listingNFTId}
              onChange={(e) => setListingNFTId(e.target.value)}
            />
            <input
              type="text"
              placeholder="Price in Tokens"
              value={listingPrice}
              onChange={(e) => setListingPrice(e.target.value)}
            />
            <button onClick={handleList} disabled={isListing}>
              {isListing ? 'Listing...' : 'List NFT'}
            </button>
          </div>
        </div>

        <div className="right-section">
          <div className="approve-token">
            <h3>Approve Token</h3>
            <input
              type="text"
              placeholder="Token Amount"
              value={buyingPrice}
              onChange={(e) => setBuyingPrice(e.target.value)}
            />
            <button onClick={handleApproveToken} disabled={isApprovingToken}>
              {isApprovingToken ? 'Approving Token...' : 'Approve Token'}
            </button>
          </div>

          <div className="buy-nft">
            <h3>Buy NFT</h3>
            <input
              type="text"
              placeholder="NFT Token ID"
              value={buyingNFTId}
              onChange={(e) => setBuyingNFTId(e.target.value)}
            />
            <button onClick={handleBuy} disabled={isBuying}>
              {isBuying ? 'Buying...' : 'Buy NFT'}
            </button>
          </div>
        </div>
      </div>

      <div className="nft-lists">
        <div className="list-header">
          <h3>NFT Lists</h3>
          <button 
            className="refresh-button" 
            onClick={fetchNFTLists} 
            disabled={isRefreshing}
          >
            {isRefreshing ? 'Refreshing...' : '🔄 Refresh Lists'}
          </button>
        </div>

        <div className="market-nfts">
          <h3>Market NFTs</h3>
          {isLoading ? (
            <p>Loading market NFTs...</p>
          ) : marketNFTs.length > 0 ? (
            <div className="nft-grid">
              {marketNFTs.map((tokenId) => (
                <div key={tokenId} className="nft-item">
                  <p>NFT #{tokenId}</p>
                  <button 
                    onClick={() => {
                      setBuyingNFTId(tokenId.toString())
                      document.querySelector('.buy-nft')?.scrollIntoView({ behavior: 'smooth' })
                    }}
                  >
                    Buy This NFT
                  </button>
                </div>
              ))}
            </div>
          ) : (
            <p>No NFTs in market</p>
          )}
        </div>

        <div className="user-nfts">
          <h3>Your NFTs</h3>
          {isLoading ? (
            <p>Loading your NFTs...</p>
          ) : userNFTs.length > 0 ? (
            <div className="nft-grid">
              {userNFTs.map((tokenId) => (
                <div key={tokenId} className="nft-item">
                  <p>NFT TokenID {tokenId}</p>
                  <button 
                    onClick={() => {
                      setListingNFTId(tokenId.toString())
                      document.querySelector('.list-nft')?.scrollIntoView({ behavior: 'smooth' })
                    }}
                  >
                    List This NFT
                  </button>
                </div>
              ))}
            </div>
          ) : (
            <p>You don't own any NFTs</p>
          )}
        </div>
      </div>
    </div>
  )
} 