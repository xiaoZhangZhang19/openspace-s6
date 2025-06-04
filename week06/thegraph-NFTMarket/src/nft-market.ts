import {
  NFTListed as NFTListedEvent,
  NFTPurchased as NFTPurchasedEvent
} from "../generated/NFTMarket/NFTMarket"
import {
  NFTListed,
  NFTPurchased
} from "../generated/schema"
import { BigInt, Bytes } from "@graphprotocol/graph-ts"

export function handleNFTListed(event: NFTListedEvent): void {
  // 使用 nftContract 和 tokenId 的组合作为实体 ID
  let id = event.params.nftContract.toHexString().concat("-").concat(event.params.tokenId.toString())
  let entity = new NFTListed(Bytes.fromUTF8(id))
  
  entity.nftContract = event.params.nftContract
  entity.tokenId = event.params.tokenId
  entity.seller = event.params.seller
  entity.tokenContract = event.params.tokenContract
  entity.price = event.params.price

  entity.blockNumber = event.block.number
  entity.blockTimestamp = event.block.timestamp
  entity.transactionHash = event.transaction.hash

  entity.save()
}

export function handleNFTPurchased(event: NFTPurchasedEvent): void {
  let entity = new NFTPurchased(
    event.transaction.hash.concatI32(event.logIndex.toI32())
  )
  entity.nftContract = event.params.nftContract
  entity.tokenId = event.params.tokenId
  entity.buyer = event.params.buyer
  entity.seller = event.params.seller
  entity.price = event.params.price

  entity.blockNumber = event.block.number
  entity.blockTimestamp = event.block.timestamp
  entity.transactionHash = event.transaction.hash
  
  // 查找对应的 NFTListed 实体
  // 使用与 handleNFTListed 相同的 ID 生成逻辑
  let id = event.params.nftContract.toHexString().concat("-").concat(event.params.tokenId.toString())
  let nftListedId = Bytes.fromUTF8(id)
  let nftListed = NFTListed.load(nftListedId);
  
  if (nftListed != null) {
    entity.nftListed = nftListed.id;
  } else {
    // 如果找不到对应的 NFTListed 实体，可以创建一个默认值或记录错误
    // 在实际应用中，你可能需要更复杂的逻辑来处理这种情况
    // 使用默认的 ID 格式，确保它是 Bytes 类型
    entity.nftListed = nftListedId;
  }

  entity.save()
}