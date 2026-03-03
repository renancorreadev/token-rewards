-include .env

.PHONY: install update build clean sizes test test-v test-gas coverage \
        slither echidna halmos security deploy deploy-verify deploy-dry \
        anvil deploy-local fmt fmt-check snapshot all

# ——— Setup ———
install:
	forge install

update:
	forge update

# ——— Build ———
build:
	forge build

clean:
	forge clean

sizes:
	forge build --sizes

# ——— Test ———
test:
	forge test

test-v:
	forge test -vvv

test-gas:
	forge test --gas-report

coverage:
	forge coverage

# ——— Security ———
slither:
	slither src/TokenRewards.sol

echidna:
	echidna test/echidna/TokenRewardsEchidna.sol --contract TokenRewardsEchidna --config test/echidna/echidna.yaml

halmos:
	halmos --contract TokenRewardsHalmosTest

security: slither echidna halmos

# ——— Deploy ———
deploy:
	forge script script/TokenRewards.s.sol:TokenRewardsScript --rpc-url $(RPC_URL) --private-key $(PRIVATE_KEY) --broadcast

deploy-verify:
	forge script script/TokenRewards.s.sol:TokenRewardsScript --rpc-url $(RPC_URL) --private-key $(PRIVATE_KEY) --broadcast --verify --etherscan-api-key $(ETHERSCAN_API_KEY)

deploy-dry:
	forge script script/TokenRewards.s.sol:TokenRewardsScript --rpc-url $(RPC_URL) --private-key $(PRIVATE_KEY)

# ——— Local ———
anvil:
	anvil

deploy-local:
	forge script script/TokenRewards.s.sol:TokenRewardsScript --rpc-url http://localhost:8545 --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 --broadcast

# ——— Formatação ———
fmt:
	forge fmt

fmt-check:
	forge fmt --check

# ——— Utilitários ———
snapshot:
	forge snapshot

all: clean build test fmt-check
