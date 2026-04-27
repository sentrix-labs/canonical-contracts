.PHONY: help install build test fuzz invariant fmt lint snapshot coverage abi storage clean

help:
	@echo "Targets:"
	@echo "  install      forge install dependencies (forge-std + openzeppelin)"
	@echo "  build        forge build --sizes"
	@echo "  test         forge test -vvv"
	@echo "  fuzz         forge test --match-path test/fuzz/*"
	@echo "  invariant    forge test --match-path test/invariant/*"
	@echo "  fmt          forge fmt"
	@echo "  lint         solhint contracts/**/*.sol"
	@echo "  snapshot     forge snapshot --check"
	@echo "  coverage     forge coverage --report lcov (output: coverage/lcov.info)"
	@echo "  abi          ./script/copy-abi.sh"
	@echo "  storage      regenerate docs/storage/*.json"
	@echo "  clean        forge clean"

install:
	forge install --no-commit foundry-rs/forge-std@v1.9.4 || true
	forge install --no-commit OpenZeppelin/openzeppelin-contracts@v5.0.2 || true

build:
	forge build --sizes

test:
	forge test -vvv

fuzz:
	forge test --match-path "test/fuzz/*" -vvv

invariant:
	forge test --match-path "test/invariant/*" -vvv

fmt:
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

clean:
	forge clean
	rm -rf coverage/
