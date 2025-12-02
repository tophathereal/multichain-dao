// scripts/test-connection.js
const { ethers } = require('ethers');
const config = require('../config');

async function testConnection() {
    console.log('=== Testing RPC Connections ===\n');

    // Test Source Chain (Sepolia)
    console.log('1. Testing Source Chain (Sepolia)...');
    console.log(`   RPC: ${config.sourceChain.rpcUrl}`);
    
    try {
        const sourceProvider = new ethers.JsonRpcProvider(config.sourceChain.rpcUrl);
        
        console.log('   Fetching network info...');
        const network = await sourceProvider.getNetwork();
        console.log(`   ✅ Connected to chain ID: ${network.chainId}`);
        
        console.log('   Fetching block number...');
        const blockNumber = await sourceProvider.getBlockNumber();
        console.log(`   ✅ Current block: ${blockNumber}`);
        
        console.log('   Checking wallet balance...');
        const wallet = new ethers.Wallet(config.relayer.privateKey, sourceProvider);
        const balance = await sourceProvider.getBalance(wallet.address);
        console.log(`   ✅ Relayer address: ${wallet.address}`);
        console.log(`   ✅ Balance: ${ethers.formatEther(balance)} ETH`);
        
        console.log('   Checking bridge contract...');
        const code = await sourceProvider.getCode(config.sourceChain.bridgeAddress);
        if (code === '0x') {
            console.log(`   ❌ No contract at bridge address: ${config.sourceChain.bridgeAddress}`);
        } else {
            console.log(`   ✅ Bridge contract exists at: ${config.sourceChain.bridgeAddress}`);
        }
        
    } catch (error) {
        console.log(`   ❌ Source chain error: ${error.message}`);
        return false;
    }

    console.log('\n2. Testing Local Chain (Geth)...');
    console.log(`   RPC: ${config.localChain.rpcUrl}`);
    
    try {
        const localProvider = new ethers.JsonRpcProvider(config.localChain.rpcUrl);
        
        console.log('   Fetching network info...');
        const network = await localProvider.getNetwork();
        console.log(`   ✅ Connected to chain ID: ${network.chainId}`);
        
        console.log('   Fetching block number...');
        const blockNumber = await localProvider.getBlockNumber();
        console.log(`   ✅ Current block: ${blockNumber}`);
        
        if (blockNumber === 0) {
            console.log('   ⚠️  Warning: Block number is 0. Chain might not be mining.');
            console.log('   💡 Tip: Send a transaction to trigger block production');
        }
        
        console.log('   Checking wallet balance...');
        const wallet = new ethers.Wallet(config.relayer.privateKey, localProvider);
        const balance = await localProvider.getBalance(wallet.address);
        console.log(`   ✅ Relayer address: ${wallet.address}`);
        console.log(`   ✅ Balance: ${ethers.formatEther(balance)} ETH`);
        
        if (balance === 0n) {
            console.log('   ⚠️  Warning: Relayer has no ETH on local chain!');
            console.log('   💡 Fund the relayer to pay for gas');
        }
        
        console.log('   Checking bridge contract...');
        const code = await localProvider.getCode(config.localChain.bridgeAddress);
        if (code === '0x') {
            console.log(`   ❌ No contract at bridge address: ${config.localChain.bridgeAddress}`);
        } else {
            console.log(`   ✅ Bridge contract exists at: ${config.localChain.bridgeAddress}`);
        }
        
    } catch (error) {
        console.log(`   ❌ Local chain error: ${error.message}`);
        return false;
    }

    console.log('\n=== Summary ===');
    console.log('✅ All connections successful!');
    console.log('\nRelayer is ready to start.');
    return true;
}

testConnection()
    .then(success => {
        process.exit(success ? 0 : 1);
    })
    .catch(error => {
        console.error('Fatal error:', error);
        process.exit(1);
    });

