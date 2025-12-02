.PHONY: help build clean test deploy-sepolia deploy-amoy set-peers send-tokens generate-abi

# Default target
.DEFAULT_GOAL := help

# Network RPC endpoints (from foundry.toml)
SEPOLIA_RPC := sepolia
AMOY_RPC := amoy
LOCAL_RPC := local

# Deployment script paths
DEPLOY_SCRIPT := script/Deploy.s.sol
DEPLOY_CONTRACT := DeployVotesOFT
SET_PEERS_CONTRACT := SetPeers
SEND_TOKENS_CONTRACT := SendTokens

# Build output directories
OUT_DIR := out
SRC_DIR := src

##@ General

help: ## Display this help message
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

##@ Build

build: ## Build all contracts
	@echo "Building contracts..."
	forge build

clean: ## Clean build artifacts
	@echo "Cleaning build artifacts..."
	forge clean
	rm -rf $(OUT_DIR)

test: ## Run tests
	@echo "Running tests..."
	forge test -vv

snapshot: ## Generate gas snapshot
	@echo "Generating gas snapshot..."
	forge snapshot

##@ Deployment

deploy-sepolia: build ## Deploy VotesOFT, NSToken, and MultiTokenGovernor to Sepolia
	@echo "Deploying to Sepolia..."
	@if [ -z "$$PRIVATE_KEY" ]; then \
		echo "Error: PRIVATE_KEY environment variable not set"; \
		exit 1; \
	fi
	forge script $(DEPLOY_SCRIPT):$(DEPLOY_CONTRACT) \
		--rpc-url $(SEPOLIA_RPC) \
		--broadcast \
		--verify \
		-vvvv

deploy-amoy: build ## Deploy VotesOFT to Amoy
	@echo "Deploying to Amoy..."
	@if [ -z "$$PRIVATE_KEY" ]; then \
		echo "Error: PRIVATE_KEY environment variable not set"; \
		exit 1; \
	fi
	forge script $(DEPLOY_SCRIPT):$(DEPLOY_CONTRACT) \
		--rpc-url $(AMOY_RPC) \
		--broadcast \
		--verify \
		-vvvv

deploy-local: build ## Deploy to local network
	@echo "Deploying to local network..."
	@if [ -z "$$PRIVATE_KEY" ]; then \
		echo "Error: PRIVATE_KEY environment variable not set"; \
		exit 1; \
	fi
	forge script $(DEPLOY_SCRIPT):$(DEPLOY_CONTRACT) \
		--rpc-url $(LOCAL_RPC) \
		--broadcast \
		-vvvv

deploy-all: deploy-sepolia deploy-amoy ## Deploy to both Sepolia and Amoy sequentially
	@echo "Deployment to both chains complete!"

##@ Configuration

set-peers-sepolia: ## Set peer on Sepolia (requires LOCAL_OFT and REMOTE_OFT env vars)
	@echo "Setting peers on Sepolia..."
	@if [ -z "$$LOCAL_OFT" ] || [ -z "$$REMOTE_OFT" ]; then \
		echo "Error: LOCAL_OFT and REMOTE_OFT environment variables required"; \
		exit 1; \
	fi
	forge script $(DEPLOY_SCRIPT):$(SET_PEERS_CONTRACT) \
		--rpc-url $(SEPOLIA_RPC) \
		--broadcast \
		-vvvv

set-peers-amoy: ## Set peer on Amoy (requires LOCAL_OFT and REMOTE_OFT env vars)
	@echo "Setting peers on Amoy..."
	@if [ -z "$$LOCAL_OFT" ] || [ -z "$$REMOTE_OFT" ]; then \
		echo "Error: LOCAL_OFT and REMOTE_OFT environment variables required"; \
		exit 1; \
	fi
	forge script $(DEPLOY_SCRIPT):$(SET_PEERS_CONTRACT) \
		--rpc-url $(AMOY_RPC) \
		--broadcast \
		-vvvv

set-peers-all: set-peers-sepolia set-peers-amoy ## Set peers on both chains
	@echo "Peers configured on both chains!"

##@ Cross-Chain Operations

send-sepolia-to-amoy: ## Send tokens from Sepolia to Amoy
	@echo "Sending tokens from Sepolia to Amoy..."
	@if [ -z "$$LOCAL_OFT" ]; then \
		echo "Error: LOCAL_OFT environment variable required"; \
		exit 1; \
	fi
	forge script $(DEPLOY_SCRIPT):$(SEND_TOKENS_CONTRACT) \
		--rpc-url $(SEPOLIA_RPC) \
		--broadcast \
		-vvvv

send-amoy-to-sepolia: ## Send tokens from Amoy to Sepolia
	@echo "Sending tokens from Amoy to Sepolia..."
	@if [ -z "$$LOCAL_OFT" ]; then \
		echo "Error: LOCAL_OFT environment variable required"; \
		exit 1; \
	fi
	forge script $(DEPLOY_SCRIPT):$(SEND_TOKENS_CONTRACT) \
		--rpc-url $(AMOY_RPC) \
		--broadcast \
		-vvvv

##@ ABI Generation

generate-abi: build ## Generate ABI JSON files for frontend
	@echo "Generating ABI files..."
	@mkdir -p abi
	@jq '.abi' $(OUT_DIR)/VotesOFT.sol/VotesOFT.json > frontend/VotesOFT.json
	@jq '.abi' $(OUT_DIR)/NSToken.sol/NSToken.json > frontend/NSToken.json
	@jq '.abi' $(OUT_DIR)/MyGovernor.sol/MultiTokenGovernor.json > frontend/MultiTokenGovernor.json
	@echo "ABI files generated in ./abi directory"

##@ Infrastructure
infra-init: ## Initialize OpenTofu
	@cd terraform && tofu init

infra-plan: ## Plan infrastructure
	@cd terraform && tofu plan

infra-apply: ## Apply infrastructure
	@cd terraform && tofu apply

infra-destroy: ## Destroy infrastructure
	@cd terraform && tofu destroy

infra-output: ## Show outputs
	@cd terraform && tofu output

infra-deploy:
	@wrangler pages deploy frontend \
		--project-name=multi-chain-governance \
		--branch=main

##@ Verification

verify-contract: ## Verify a contract (usage: make verify-contract CHAIN=sepolia ADDRESS=0x...)
	@if [ -z "$$ADDRESS" ] || [ -z "$$CHAIN" ]; then \
		echo "Error: ADDRESS and CHAIN variables required"; \
		echo "Usage: make verify-contract CHAIN=sepolia ADDRESS=0x..."; \
		exit 1; \
	fi
	forge verify-contract $(ADDRESS) \
		--chain-id $$(forge script --rpc-url $(CHAIN) -vv --sig "run()" | grep "Chain ID" | awk '{print $$3}') \
		--watch

##@ Utility

format: ## Format Solidity files
	@echo "Formatting contracts..."
	forge fmt

check-format: ## Check if contracts are formatted
	@echo "Checking formatting..."
	forge fmt --check

install-deps: ## Install/update dependencies
	@echo "Installing dependencies..."
	forge install

update-deps: ## Update dependencies
	@echo "Updating dependencies..."
	forge update

env-check: ## Check if required environment variables are set
	@echo "Checking environment variables..."
	@if [ -z "$$PRIVATE_KEY" ]; then \
		echo "❌ PRIVATE_KEY not set"; \
	else \
		echo "✓ PRIVATE_KEY is set"; \
	fi
