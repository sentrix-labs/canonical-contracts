.PHONY: help install build test fuzz invariant fmt format lint snapshot coverage abi storage deploy-test deploy-main check-test check-main verify clean

help:
	@echo "Targets:"
	@echo "  install         forge install dependencies (forge-std)"
	@echo "  build           forge build --sizes"
	@echo "  test            forge test -vvv"
	@echo "  fuzz            forge test --match-path test/fuzz/*"
	@echo "  invariant       forge test --match-path test/invariant/*"
	@echo "  fmt / format    forge fmt"
	@echo "  lint            solhint contracts/**/*.sol"
	@echo "  snapshot        forge snapshot --check"
	@echo "  coverage        forge coverage --report lcov (output: coverage/lcov.info)"
	@echo "  abi             ./script/copy-abi.sh"
	@echo "  storage         regenerate docs/storage/*.json"
	@echo "  deploy-test     forge script all 4 deploys -> sentrix_testnet (needs DEPLOYER_PRIVATE_KEY env)"
	@echo "  deploy-main     forge script all 4 deploys -> sentrix_mainnet (needs DEPLOYER_PRIVATE_KEY env)"
	@echo "  check-test      forge script CheckDeployment -> sentrix_testnet"
	@echo "  check-main      forge script CheckDeployment -> sentrix_mainnet"
	@echo "  verify          forge script VerifyAll (logs manual verify cmds until Sourcify lands)"
	@echo "  clean           forge clean"

install:
	forge install foundry-rs/forge-std

build:
	forge build --sizes

test:
	forge test -vvv

fuzz:
	forge test --match-path "test/fuzz/*" -vvv

invariant:
	forge test --match-path "test/invariant/*" -vvv

fmt format:
	forge fmt

lint:
	solhint "contracts/**/*.sol"

snapshot:
	forge snapshot --check

coverage:
	mkdir -p coverage
	forge coverage --report lcov --report-file coverage/lcov.info

abi: build
	./script/copy-abi.sh

storage: build
	mkdir -p docs/storage
	forge inspect WSRX storage-layout > docs/storage/WSRX.json
	forge inspect Multicall3 storage-layout > docs/storage/Multicall3.json
	forge inspect SentrixSafe storage-layout > docs/storage/SentrixSafe.json
	forge inspect TokenFactory storage-layout > docs/storage/TokenFactory.json

deploy-test: build
	forge script script/DeployWSRX.s.sol:DeployWSRX --rpc-url sentrix_testnet --broadcast --private-key $$DEPLOYER_PRIVATE_KEY
	forge script script/DeployMulticall3.s.sol:DeployMulticall3 --rpc-url sentrix_testnet --broadcast --private-key $$DEPLOYER_PRIVATE_KEY
	forge script script/DeploySafe.s.sol:DeploySafe --rpc-url sentrix_testnet --broadcast --private-key $$DEPLOYER_PRIVATE_KEY
	forge script script/DeployFactory.s.sol:DeployFactory --rpc-url sentrix_testnet --broadcast --private-key $$DEPLOYER_PRIVATE_KEY

deploy-main: build
	@echo "Mainnet deploy - confirm with Ctrl-C if not intended (5s)..."
	@sleep 5
	forge script script/DeployWSRX.s.sol:DeployWSRX --rpc-url sentrix_mainnet --broadcast --private-key $$DEPLOYER_PRIVATE_KEY
	forge script script/DeployMulticall3.s.sol:DeployMulticall3 --rpc-url sentrix_mainnet --broadcast --private-key $$DEPLOYER_PRIVATE_KEY
	forge script script/DeploySafe.s.sol:DeploySafe --rpc-url sentrix_mainnet --broadcast --private-key $$DEPLOYER_PRIVATE_KEY
	forge script script/DeployFactory.s.sol:DeployFactory --rpc-url sentrix_mainnet --broadcast --private-key $$DEPLOYER_PRIVATE_KEY

check-test:
	forge script script/CheckDeployment.s.sol:CheckDeployment --rpc-url sentrix_testnet

check-main:
	forge script script/CheckDeployment.s.sol:CheckDeployment --rpc-url sentrix_mainnet

verify:
	forge script script/VerifyAll.s.sol:VerifyAll --rpc-url sentrix_testnet

clean:
	forge clean
	rm -rf coverage/
