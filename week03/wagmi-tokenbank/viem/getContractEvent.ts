'use client'
import { TokenBank2Abi } from "./abi";
import { publicClient } from "./client";
import { MyERC20ABI } from "./MyERC20";

async function watchEvents() {
    try {
        console.log('Starting to watch events...');
        
        const unwatchDeposit = publicClient.watchContractEvent({
            address: '0x4631BCAbD6dF18D94796344963cB60d44a4136b6',
            abi: TokenBank2Abi,
            eventName: 'depositLog',
            onLogs: logs => {
                console.log(logs.map(log => `depositLog: ${log.args.balance}`))
            }
        });

        const unwatchTokenReceived = publicClient.watchContractEvent({
            address: '0x4631BCAbD6dF18D94796344963cB60d44a4136b6',
            abi: TokenBank2Abi,
            eventName: 'depositByTokenReceivedLog',
            onLogs: logs => {
                console.log(logs.map(log => `TransferWithCallbackLog: ${log.args.balance}`))
            }
        });

        const unwatchWithdraw = publicClient.watchContractEvent({
            address: '0x4631BCAbD6dF18D94796344963cB60d44a4136b6',
            abi: TokenBank2Abi,
            eventName: 'withdrawLog',
            onLogs: logs => console.log(logs.map(log => `withdrawLog: ${log.args.balance}`))
        });

        // 保持进程运行
        process.on('SIGINT', () => {
            console.log('Stopping event watching...');
            unwatchDeposit();
            unwatchTokenReceived();
            unwatchWithdraw();
            process.exit();
        });

        console.log('Watching for events. Press Ctrl+C to stop.');
    } catch (error) {
        console.error('Error watching events:', error);
    }
}

watchEvents().catch(console.error);