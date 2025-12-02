// relayer.js
const { ethers } = require('ethers');
const winston = require('winston');
const express = require('express');
const path = require('path');

const config = require('./config');
const ABIs = require('./abis');

// Configure logger
const logger = winston.createLogger({
    level: config.logging.level,
    format: winston.format.combine(
        winston.format.timestamp(),
        winston.format.json()
    ),
    transports: [
        new winston.transports.Console({
            format: winston.format.simple()
        }),
        new winston.transports.File({ 
            filename: config.logging.file,
            maxsize: parseInt(config.logging.maxSize) * 1024 * 1024,
            maxFiles: config.logging.maxFiles
        })
    ]
});

class BridgeRelayer {
    constructor(cfg) {
        this.config = cfg;
        
        // Source chain setup
        this.sourceProvider = new ethers.JsonRpcProvider(cfg.sourceChain.rpcUrl);
        this.sourceWallet = new ethers.Wallet(cfg.relayer.privateKey, this.sourceProvider);
        this.sourceBridge = new ethers.Contract(
            cfg.sourceChain.bridgeAddress,
            ABIs.SourceBridge,
            this.sourceWallet
        );

        // Local chain setup
        this.localProvider = new ethers.JsonRpcProvider(cfg.localChain.rpcUrl);
        this.localWallet = new ethers.Wallet(cfg.relayer.privateKey, this.localProvider);
        this.localBridge = new ethers.Contract(
            cfg.localChain.bridgeAddress,
            ABIs.LocalBridge,
            this.localWallet
        );

        // State tracking
        this.processedLocks = new Set();
        this.processedUnlocks = new Set();
        this.stats = {
            locksRelayed: 0,
            unlocksRelayed: 0,
            errors: 0,
            startTime: Date.now(),
            lastSourceBlock: 0,
            lastLocalBlock: 0
        };
        
        // Polling intervals
        this.sourcePollingInterval = null;
        this.localPollingInterval = null;
        this.healthCheckInterval = null;
        this.backupInterval = null;
        
        this.loadProcessedTransactions();
    }

    async start() {
        logger.info('=== Bridge Relayer Starting (Polling Mode) ===');
        logger.info(`Source: ${this.config.sourceChain.name} (${this.config.sourceChain.chainId})`);
        logger.info(`Local: ${this.config.localChain.name} (${this.config.localChain.chainId})`);
        logger.info(`Relayer: ${this.sourceWallet.address}`);
        logger.info(`Source polling: every ${this.config.polling.sourceInterval / 1000}s`);
        logger.info(`Local polling: every ${this.config.polling.localInterval / 1000}s`);

        // Initialize last block numbers
        try {
            this.stats.lastSourceBlock = await this.sourceProvider.getBlockNumber();
            this.stats.lastLocalBlock = await this.localProvider.getBlockNumber();
            logger.info(`Starting from source block: ${this.stats.lastSourceBlock}`);
            logger.info(`Starting from local block: ${this.stats.lastLocalBlock}`);
        } catch (error) {
            logger.error(`Failed to get initial block numbers: ${error.message}`);
            throw error;
        }

        // Start polling loops
        this.startSourcePolling();
        this.startLocalPolling();

        // Health check interval
        this.healthCheckInterval = setInterval(
            () => this.healthCheck(), 
            this.config.monitoring.healthCheckInterval
        );

        // Backup state periodically
        this.backupInterval = setInterval(
            () => this.saveProcessedTransactions(), 
            this.config.storage.backupInterval
        );

        logger.info('✅ Relayer started successfully');
    }

    /**
     * Start polling source chain for lock events
     */
    startSourcePolling() {
        logger.info('Starting source chain polling...');
        
        // Poll immediately, then on interval
        this.pollSourceChain();
        
        this.sourcePollingInterval = setInterval(
            () => this.pollSourceChain(),
            this.config.polling.sourceInterval
        );
    }

    /**
     * Poll source chain for new lock events
     */
    async pollSourceChain() {
        try {
            const currentBlock = await this.sourceProvider.getBlockNumber();
            
            if (currentBlock <= this.stats.lastSourceBlock) {
                logger.debug(`Source chain: No new blocks (current: ${currentBlock})`);
                return;
            }

            const fromBlock = this.stats.lastSourceBlock + 1;
            const toBlock = Math.min(
                currentBlock, 
                fromBlock + this.config.polling.maxBlockRange - 1
            );

            logger.debug(`Polling source chain blocks ${fromBlock} to ${toBlock}`);

            const filter = this.sourceBridge.filters.TokensLocked();
            const events = await this.sourceBridge.queryFilter(filter, fromBlock, toBlock);

            logger.info(`Found ${events.length} lock events in blocks ${fromBlock}-${toBlock}`);

            for (const event of events) {
                await this.processLockEvent(event);
            }

            // Update last processed block
            this.stats.lastSourceBlock = toBlock;

        } catch (error) {
            logger.error(`Error polling source chain: ${error.message}`);
            this.stats.errors++;
        }
    }

    /**
     * Process a single lock event
     */
    async processLockEvent(event) {
        try {
            const txHash = event.transactionHash;
            const [from, amount, destinationChainId, timestamp] = event.args;
            
            if (this.processedLocks.has(txHash)) {
                logger.debug(`Lock ${txHash} already processed`);
                return;
            }

            logger.info(`🔒 New lock detected: ${txHash}`);
            logger.info(`  Block: ${event.blockNumber}`);
            logger.info(`  From: ${from}`);
            logger.info(`  Amount: ${ethers.formatEther(amount)}`);
            logger.info(`  Timestamp: ${timestamp}`);

            if (Number(destinationChainId) !== this.config.localChain.chainId) {
                logger.warn(`Chain ID mismatch: ${destinationChainId} != ${this.config.localChain.chainId}`);
                return;
            }

            const signature = await this.signLockEvent(txHash, from, amount, timestamp);
            await this.relayLockToLocal(txHash, from, amount, timestamp, signature);

            this.processedLocks.add(txHash);
            this.stats.locksRelayed++;
            this.saveProcessedTransactions();

            logger.info(`✅ Lock ${txHash} relayed successfully`);

        } catch (error) {
            logger.error(`❌ Error processing lock event: ${error.message}`);
            logger.error(error.stack);
            this.stats.errors++;
        }
    }

    /**
     * Start polling local chain for unlock events
     */
    startLocalPolling() {
        logger.info('Starting local chain polling...');
        
        // Poll immediately, then on interval
        this.pollLocalChain();
        
        this.localPollingInterval = setInterval(
            () => this.pollLocalChain(),
            this.config.polling.localInterval
        );
    }

    /**
     * Poll local chain for new unlock events
     */
    async pollLocalChain() {
        try {
            const currentBlock = await this.localProvider.getBlockNumber();
            
            if (currentBlock <= this.stats.lastLocalBlock) {
                logger.debug(`Local chain: No new blocks (current: ${currentBlock})`);
                return;
            }

            const fromBlock = this.stats.lastLocalBlock + 1;
            const toBlock = Math.min(
                currentBlock, 
                fromBlock + this.config.polling.maxBlockRange - 1
            );

            logger.debug(`Polling local chain blocks ${fromBlock} to ${toBlock}`);

            const filter = this.localBridge.filters.TokensUnlocked();
            const events = await this.localBridge.queryFilter(filter, fromBlock, toBlock);

            logger.info(`Found ${events.length} unlock events in blocks ${fromBlock}-${toBlock}`);

            for (const event of events) {
                await this.processUnlockEvent(event);
            }

            // Update last processed block
            this.stats.lastLocalBlock = toBlock;

        } catch (error) {
            logger.error(`Error polling local chain: ${error.message}`);
            this.stats.errors++;
        }
    }

    /**
     * Process a single unlock event
     */
    async processUnlockEvent(event) {
        try {
            const [burnTxHash, to, amount] = event.args;
            
            if (this.processedUnlocks.has(burnTxHash)) {
                logger.debug(`Unlock ${burnTxHash} already processed`);
                return;
            }

            logger.info(`🔓 New unlock request: ${burnTxHash}`);
            logger.info(`  Block: ${event.blockNumber}`);
            logger.info(`  To: ${to}`);
            logger.info(`  Amount: ${ethers.formatEther(amount)}`);

            await this.relayUnlockToSource(burnTxHash, to, amount);

            this.processedUnlocks.add(burnTxHash);
            this.stats.unlocksRelayed++;
            this.saveProcessedTransactions();

            logger.info(`✅ Unlock ${burnTxHash} relayed successfully`);

        } catch (error) {
            logger.error(`❌ Error processing unlock event: ${error.message}`);
            logger.error(error.stack);
            this.stats.errors++;
        }
    }

    async signLockEvent(txHash, from, amount, sourceChainTimestamp) {
        const message = ethers.solidityPackedKeccak256(
            ['uint64', 'address', 'address', 'bytes32', 'address', 'uint256', 'uint256'],
            [
                this.config.sourceChain.chainId,
                this.config.sourceChain.bridgeAddress,
                this.config.sourceChain.tokenAddress,
                txHash,
                from,
                amount,
                sourceChainTimestamp
            ]
        );

        return await this.sourceWallet.signMessage(ethers.getBytes(message));
    }

    async relayLockToLocal(txHash, from, amount, sourceChainTimestamp, signature) {
        try {
            logger.info(`Relaying lock to local chain...`);

            const tx = await this.localBridge.relayLock(
                txHash,
                from,
                amount,
                sourceChainTimestamp,
                signature,
                { gasLimit: this.config.gas.relayLockLimit }
            );

            logger.info(`Transaction sent: ${tx.hash}`);
            const receipt = await tx.wait();
            logger.info(`Confirmed in block ${receipt.blockNumber}`);

            return receipt;

        } catch (error) {
            if (error.message.includes('TransactionAlreadyProcessed')) {
                logger.warn(`Lock ${txHash} already processed on local chain`);
                return;
            }
            throw error;
        }
    }

    async relayUnlockToSource(burnTxHash, to, amount) {
        try {
            logger.info(`Relaying unlock to source chain...`);

            const tx = await this.sourceBridge.relayUnlock(
                burnTxHash,
                to,
                amount,
                { gasLimit: this.config.gas.relayUnlockLimit }
            );

            logger.info(`Transaction sent: ${tx.hash}`);
            const receipt = await tx.wait();
            logger.info(`Confirmed in block ${receipt.blockNumber}`);

            return receipt;

        } catch (error) {
            if (error.message.includes('UnlockAlreadyProcessed')) {
                logger.warn(`Unlock ${burnTxHash} already processed on source chain`);
                return;
            }
            throw error;
        }
    }

    async healthCheck() {
        try {
            const sourceBlock = await this.sourceProvider.getBlockNumber();
            const localBlock = await this.localProvider.getBlockNumber();
            const sourceBalance = await this.sourceProvider.getBalance(this.sourceWallet.address);
            const localBalance = await this.localProvider.getBalance(this.localWallet.address);

            const uptimeSeconds = Math.floor((Date.now() - this.stats.startTime) / 1000);
            const sourceLag = sourceBlock - this.stats.lastSourceBlock;
            const localLag = localBlock - this.stats.lastLocalBlock;

            logger.info('=== Health Check ===');
            logger.info(`Source block: ${sourceBlock} (last processed: ${this.stats.lastSourceBlock}, lag: ${sourceLag})`);
            logger.info(`Local block: ${localBlock} (last processed: ${this.stats.lastLocalBlock}, lag: ${localLag})`);
            logger.info(`Source balance: ${ethers.formatEther(sourceBalance)} ETH`);
            logger.info(`Local balance: ${ethers.formatEther(localBalance)} ETH`);
            logger.info(`Locks relayed: ${this.stats.locksRelayed}`);
            logger.info(`Unlocks relayed: ${this.stats.unlocksRelayed}`);
            logger.info(`Errors: ${this.stats.errors}`);
            logger.info(`Uptime: ${uptimeSeconds}s`);
            logger.info('==================');

            const threshold = ethers.parseEther(this.config.monitoring.lowBalanceThreshold);
            if (sourceBalance < threshold) {
                logger.warn('⚠️  Source wallet balance is low!');
            }
            if (localBalance < threshold) {
                logger.warn('⚠️  Local wallet balance is low!');
            }

            // Warn if falling behind
            if (sourceLag > 100) {
                logger.warn(`⚠️  Source chain is ${sourceLag} blocks behind!`);
            }
            if (localLag > 100) {
                logger.warn(`⚠️  Local chain is ${localLag} blocks behind!`);
            }

        } catch (error) {
            logger.error(`Health check failed: ${error.message}`);
        }
    }

    loadProcessedTransactions() {
        try {
            const fs = require('fs');
            if (fs.existsSync(this.config.storage.processedFile)) {
                const data = JSON.parse(fs.readFileSync(this.config.storage.processedFile, 'utf8'));
                this.processedLocks = new Set(data.locks || []);
                this.processedUnlocks = new Set(data.unlocks || []);
                
                // Restore last block numbers if available
                if (data.stats) {
                    this.stats.lastSourceBlock = data.stats.lastSourceBlock || 0;
                    this.stats.lastLocalBlock = data.stats.lastLocalBlock || 0;
                }
                
                logger.info(`Loaded ${this.processedLocks.size} locks and ${this.processedUnlocks.size} unlocks`);
                logger.info(`Resuming from source block ${this.stats.lastSourceBlock}, local block ${this.stats.lastLocalBlock}`);
            }
        } catch (error) {
            logger.warn(`Could not load processed transactions: ${error.message}`);
        }
    }

    saveProcessedTransactions() {
        try {
            const fs = require('fs');
            const data = {
                locks: Array.from(this.processedLocks),
                unlocks: Array.from(this.processedUnlocks),
                stats: {
                    ...this.stats,
                    uptime: Math.floor((Date.now() - this.stats.startTime) / 1000)
                },
                lastSaved: new Date().toISOString()
            };
            fs.writeFileSync(this.config.storage.processedFile, JSON.stringify(data, null, 2));
            logger.debug('State saved to disk');
        } catch (error) {
            logger.error(`Could not save processed transactions: ${error.message}`);
        }
    }

    getStats() {
        return {
            ...this.stats,
            uptime: Math.floor((Date.now() - this.stats.startTime) / 1000),
            processedLocks: this.processedLocks.size,
            processedUnlocks: this.processedUnlocks.size
        };
    }

    stop() {
        logger.info('Stopping relayer...');
        
        if (this.sourcePollingInterval) {
            clearInterval(this.sourcePollingInterval);
        }
        if (this.localPollingInterval) {
            clearInterval(this.localPollingInterval);
        }
        if (this.healthCheckInterval) {
            clearInterval(this.healthCheckInterval);
        }
        if (this.backupInterval) {
            clearInterval(this.backupInterval);
        }
        
        this.saveProcessedTransactions();
        logger.info('Relayer stopped');
    }
}

// Initialize and start relayer
const relayer = new BridgeRelayer(config);
relayer.start().catch(error => {
    logger.error(`Fatal error: ${error.message}`);
    process.exit(1);
});

// Web dashboard (optional)
if (config.dashboard.enabled) {
    const app = express();
    
    app.get('/health', (req, res) => {
        res.json({
            status: 'ok',
            stats: relayer.getStats()
        });
    });

    app.get('/stats', (req, res) => {
        res.json(relayer.getStats());
    });

    app.get('/', (req, res) => {
        res.send(`
            <!DOCTYPE html>
            <html>
            <head>
                <title>Bridge Relayer Dashboard</title>
                <style>
                    body { font-family: monospace; padding: 20px; background: #1e1e1e; color: #d4d4d4; }
                    .stat { margin: 10px 0; }
                    .stat-label { color: #4ec9b0; }
                    .stat-value { color: #ce9178; }
                </style>
                <script>
                    setInterval(async () => {
                        const res = await fetch('/stats');
                        const stats = await res.json();
                        document.getElementById('stats').innerHTML = JSON.stringify(stats, null, 2);
                    }, 5000);
                </script>
            </head>
            <body>
                <h1>🌉 Bridge Relayer Dashboard</h1>
                <pre id="stats">Loading...</pre>
            </body>
            </html>
        `);
    });

    app.listen(config.dashboard.port, config.dashboard.host, () => {
        logger.info(`Dashboard running on http://${config.dashboard.host}:${config.dashboard.port}`);
    });
}

// Graceful shutdown
process.on('SIGINT', () => {
    logger.info('Shutting down relayer...');
    relayer.stop();
    process.exit(0);
});

process.on('SIGTERM', () => {
    logger.info('Shutting down relayer...');
    relayer.stop();
    process.exit(0);
});

module.exports = BridgeRelayer;
