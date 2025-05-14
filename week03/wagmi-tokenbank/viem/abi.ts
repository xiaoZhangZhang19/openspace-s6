export const TokenBank2Abi = [
      {
        "type": "function",
        "name": "deposit",
        "inputs": [
          {
            "name": "_depositAmount",
            "type": "uint256",
            "internalType": "uint256"
          }
        ],
        "outputs": [],
        "stateMutability": "nonpayable"
      },
      {
        "type": "function",
        "name": "tokenAddress",
        "inputs": [],
        "outputs": [
          {
            "name": "",
            "type": "address",
            "internalType": "address"
          }
        ],
        "stateMutability": "view"
      },
      {
        "type": "function",
        "name": "tokenBalances",
        "inputs": [
          {
            "name": "",
            "type": "address",
            "internalType": "address"
          }
        ],
        "outputs": [
          {
            "name": "",
            "type": "uint256",
            "internalType": "uint256"
          }
        ],
        "stateMutability": "view"
      },
      {
        "type": "function",
        "name": "tokensReceived",
        "inputs": [
          {
            "name": "_sender",
            "type": "address",
            "internalType": "address"
          },
          {
            "name": "_amount",
            "type": "uint256",
            "internalType": "uint256"
          }
        ],
        "outputs": [
          {
            "name": "",
            "type": "bool",
            "internalType": "bool"
          }
        ],
        "stateMutability": "nonpayable"
      },
      {
        "type": "function",
        "name": "withdraw",
        "inputs": [
          {
            "name": "_withdrawAmount",
            "type": "uint256",
            "internalType": "uint256"
          }
        ],
        "outputs": [],
        "stateMutability": "nonpayable"
      },
      {
        "type": "event",
        "name": "depositByTokenReceivedLog",
        "inputs": [
          {
            "name": "_addr",
            "type": "address",
            "indexed": false,
            "internalType": "address"
          },
          {
            "name": "balance",
            "type": "uint256",
            "indexed": false,
            "internalType": "uint256"
          }
        ],
        "anonymous": false
      },
      {
        "type": "event",
        "name": "depositLog",
        "inputs": [
          {
            "name": "_addr",
            "type": "address",
            "indexed": false,
            "internalType": "address"
          },
          {
            "name": "balance",
            "type": "uint256",
            "indexed": false,
            "internalType": "uint256"
          }
        ],
        "anonymous": false
      },
      {
        "type": "event",
        "name": "withdrawLog",
        "inputs": [
          {
            "name": "_addr",
            "type": "address",
            "indexed": false,
            "internalType": "address"
          },
          {
            "name": "balance",
            "type": "uint256",
            "indexed": false,
            "internalType": "uint256"
          }
        ],
        "anonymous": false
      }
] as const;