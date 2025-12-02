#!/usr/bin/env python3
import json
import os
import time
from web3 import Web3
from web3.middleware import ExtraDataToPOAMiddleware

#############################
# Configuration
#############################

# RPC endpoints
LOCAL_RPC   = os.getenv("LOCAL_RPC",   "http://192.168.45.151:8545")   # local geth/anvil
SEPOLIA_RPC = os.getenv("SEPOLIA_RPC", "https://rpc.sepolia.org")      # or Infura/Alchemy URL

# Chain IDs
LOCAL_CHAIN_ID   = int(os.getenv("LOCAL_CHAIN_ID", "1337"))
SEPOLIA_CHAIN_ID = 11155111  # Sepolia chain id

# Bridge contract addresses
BRIDGE_A_ADDRESS = Web3.to_checksum_address(os.environ["BRIDGE_A_ADDRESS"])  # local STokenBridge
BRIDGE_B_ADDRESS = Web3.to_checksum_address(os.environ["BRIDGE_B_ADDRESS"])  # Sepolia STokenBridge

# Relayer account (must hold ETH on Sepolia)
RELAYER_PRIVATE_KEY = os.environ["RELAYER_PRIVATE_KEY"]
RELAYER_ADDRESS     = Web3.to_checksum_address(os.environ["RELAYER_ADDRESS"])

# ABI paths
BRIDGE_A_ABI_PATH = os.getenv("BRIDGE_A_ABI", "BridgeA.abi.json")
BRIDGE_B_ABI_PATH = os.getenv("BRIDGE_B_ABI", "BridgeB.abi.json")

POLL_INTERVAL = float(os.getenv("POLL_INTERVAL", "5.0"))  # seconds

#############################
# Helpers
#############################

def load_abi(path):
    with open(path, "r") as f:
        return json.load(f)

def mk_w3(rpc_url, chain_id):
    w3 = Web3(Web3.HTTPProvider(rpc_url))
    # Add PoA middleware for Sepolia (extraData length quirk)
    if chain_id == SEPOLIA_CHAIN_ID:
        w3.middleware_onion.inject(ExtraDataToPOAMiddleware, layer=0)
    assert w3.is_connected(), f"Failed to connect to {rpc_url}"
    return w3

#############################
# Setup web3 + contracts
#############################

w3_local   = mk_w3(LOCAL_RPC, LOCAL_CHAIN_ID)
w3_sepolia = mk_w3(SEPOLIA_RPC, SEPOLIA_CHAIN_ID)

bridge_a_abi = load_abi(BRIDGE_A_ABI_PATH)
bridge_b_abi = load_abi(BRIDGE_B_ABI_PATH)

bridge_a = w3_local.eth.contract(address=BRIDGE_A_ADDRESS, abi=bridge_a_abi)
bridge_b = w3_sepolia.eth.contract(address=BRIDGE_B_ADDRESS, abi=bridge_b_abi)

# Event object from BridgeA ABI
TokensSent = bridge_a.events.TokensSent

#############################
# Core relay logic
#############################

def handle_tokens_sent(event):
    """
    Called when a TokensSent event is seen on BridgeA (local chain).
    It sends a tx to BridgeB on Sepolia to mint tokens.
    """
    args = event["args"]
    sender      = args["sender"]
    to          = args["to"]
    amount      = args["amount"]
    nonce       = args["nonce"]
    dst_chain_id = args["dstChainId"]

    print(f"[+] TokensSent: sender={sender}, to={to}, amount={amount}, nonce={nonce}, dstChainId={dst_chain_id}")

    # Only relay if destination is Sepolia (optional guard)
    if dst_chain_id != SEPOLIA_CHAIN_ID:
        print(f"[-] Skip event with dstChainId={dst_chain_id}")
        return

    # Build tx to BridgeB.mintFromRemote(to, amount, nonce, srcChainId=LOCAL_CHAIN_ID)
    tx = bridge_b.functions.mintFromRemote(
        to,
        amount,
        nonce,
        LOCAL_CHAIN_ID,
    ).build_transaction({
        "from": RELAYER_ADDRESS,
        "nonce": w3_sepolia.eth.get_transaction_count(RELAYER_ADDRESS),
        "gas": 300000,  # tune as needed
        "maxFeePerGas": w3_sepolia.eth.gas_price,
        "maxPriorityFeePerGas": w3_sepolia.eth.gas_price,
        "chainId": SEPOLIA_CHAIN_ID,
    })

    signed  = w3_sepolia.eth.account.sign_transaction(tx, private_key=RELAYER_PRIVATE_KEY)
    tx_hash = w3_sepolia.eth.send_raw_transaction(signed.rawTransaction)
    print(f"[+] Sent mintFromRemote tx: {tx_hash.hex()}")
    receipt = w3_sepolia.eth.wait_for_transaction_receipt(tx_hash)
    print(f"[+] Mint tx mined in block {receipt.blockNumber}")

def main():
    # Start event filter for new TokensSent events
    event_filter = TokensSent.create_filter(from_block="latest")

    print("[*] Relay running. Listening for TokensSent on local chain...")
    while True:
        try:
            for event in event_filter.get_new_entries():
                handle_tokens_sent(event)
        except Exception as e:
            print(f"[!] Error in poll loop: {e}")
        time.sleep(POLL_INTERVAL)

if __name__ == "__main__":
    main()

if __name__ == "__main__":
    main()
