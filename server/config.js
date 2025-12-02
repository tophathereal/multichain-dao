// config.js
require('dotenv').config();

/**
 * Relayer Configuration
 * Separated for easy management and testing
 */
module.exports = {
    // Relayer wallet
    relayer: {
        privateKey: '0x05d842c1189b78bbcea8509e10803b51699aa996861d6c178d0884dc82639062',
        address: '0xF99d404c92A19201F4da51fD4AbafCaa9518E185'
    },

    // Source chain configuration (Ethereum Sepolia)
    sourceChain: {
        name: 'Sepolia',
        chainId: 11155111,
        rpcUrl: 'https://sepolia.infura.io/v3/86a0d6c500904bd3b7b812a46302956d',
        bridgeAddress: '0xA92ca63F43006b3798876B99B4185914f9E0F3b8',
        tokenAddress: '0x9e00b8629E3cE42D723c036Ad0EA3A3CD04Bdd12',
    },

    // Local chain configuration (Geth)
    localChain: {
        name: 'LocalGeth',
        chainId: 1337,
        rpcUrl: 'http://192.168.45.151:8545',
        bridgeAddress: '0xCBb1f643565c1d7ea076Ee0937Cf2E999Ffc6b9D',
        wrappedTokenAddress: '0x918D289aa892D62dF8A1EF8E18D58C180D0e0875'
    },

      // Polling settings
    polling: {
        sourceInterval: 12000, // 12 seconds
        localInterval: 2000,    // 2 seconds
        maxBlockRange: 100          // Max blocks per query
    },

    // Monitoring settings
    monitoring: {
        healthCheckInterval: 60000, // 1 minute
        blockLookback: 1000, // How many blocks to scan on startup
        lowBalanceThreshold: '0.01', // ETH - warn if below this
        eventBatchSize: 10 // Process events in batches
    },

    // Gas settings
    gas: {
        relayLockLimit: 300000,
        relayUnlockLimit: 200000,
        gasMultiplier: 1.2 // 20% buffer
    },

    // Logging
    logging: {
        level: 'info',
        file:  'relayer.log',
        maxSize: '10m',
        maxFiles: 3
    },

    // Web dashboard
    dashboard: {
        enabled: 'false',
        port: 80,
        host: '0.0.0.0'
    },

    // Storage
    storage: {
        processedFile:  'processed.json',
        backupInterval: 300000 // 5 minutes
    }
};

