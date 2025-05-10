import { NFTMarketABI } from "./NFTMarketABI.js";
import { publicClient } from "./client.js";
import { Log } from 'viem';


// token address: 0xc3e53F4d16Ae77Db1c982e75a937B9f60FE63690
// nft address: 0xE6E340D132b5f46d1e472DebcD681B2aBc16e57E
// nftMarket address: 0x84eA74d481Ee0A5332c457a4d796187F6Ba67fEB

export async function getMarketEvent() {
    try {
        console.log('Starting to watch market events...');
        
        const unwatchList = await publicClient.watchContractEvent({
            address: '0x84eA74d481Ee0A5332c457a4d796187F6Ba67fEB',
            abi: NFTMarketABI,
            eventName: 'NFTListed',
            onLogs: (logs: Log[]) => {
                console.log('NFTListed event received:', logs);
            }
        });

        const unwatchPurchase = await publicClient.watchContractEvent({
            address: '0x84eA74d481Ee0A5332c457a4d796187F6Ba67fEB',
            abi: NFTMarketABI,
            eventName: 'NFTPurchased',
            onLogs: (logs: Log[]) => {
                console.log('NFTPurchased event received:', logs);
            }
        });

        const unwatchNFTPurchasedByTokenReceived = await publicClient.watchContractEvent({
            address: '0x84eA74d481Ee0A5332c457a4d796187F6Ba67fEB',
            abi: NFTMarketABI,
            eventName: 'NFTPurchasedByTokenReceived',
            onLogs: (logs: Log[]) => {
                console.log('NFTPurchasedByTokenReceived event received:', logs);
            }
        });

        console.log('Successfully started watching all market events');
        
        return {
            unwatchList,
            unwatchPurchase,
            unwatchNFTPurchasedByTokenReceived
        };
    } catch (error) {
        console.error('Error setting up event listeners:', error);
        throw error;
    }
}

// 如果直接运行此文件，则启动事件监听
getMarketEvent();