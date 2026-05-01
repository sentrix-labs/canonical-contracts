# Integration Guide

How dApps integrate with the canonical contracts. Examples in JS/TS (ethers v6 + wagmi) and a placeholder for the upcoming `sentrix.js` SDK.

## Add the network

```ts
const sentrixMainnet = {
  chainId: 7119,
  name: "Sentrix Mainnet",
  rpcUrls: { default: { http: ["https://rpc.sentrixchain.com"] } },
  nativeCurrency: { name: "Sentrix", symbol: "SRX", decimals: 18 },
  blockExplorers: { default: { name: "Sentrixscan", url: "https://scan.sentrixchain.com" } },
};
```

## WSRX (Wrapped SRX)

```ts
import { ethers } from "ethers";
import wsrxAbi from "@sentrix-labs/canonical-contracts/deployments/abi/WSRX.json";
import deployments from "@sentrix-labs/canonical-contracts/deployments/7119.json";

const provider = new ethers.JsonRpcProvider("https://rpc.sentrixchain.com");
const signer  = new ethers.Wallet(privateKey, provider);
const wsrx    = new ethers.Contract(deployments.WSRX.address, wsrxAbi.abi, signer);

// Wrap 1 SRX
await wsrx.deposit({ value: ethers.parseEther("1") });

// Unwrap
await wsrx.withdraw(ethers.parseEther("0.5"));

// ERC-20 transfer
await wsrx.transfer(recipient, ethers.parseEther("0.1"));

// Approve + transferFrom
await wsrx.approve(spender, ethers.parseEther("1"));
```

### wagmi (React) example

```tsx
import { useAccount, useReadContract, useWriteContract } from "wagmi";
import { parseEther } from "viem";
import wsrxAbi from "@sentrix-labs/canonical-contracts/deployments/abi/WSRX.json";

function Wrap() {
  const { address } = useAccount();
  const { writeContract } = useWriteContract();
  const { data: balance } = useReadContract({
    address: WSRX_ADDR, abi: wsrxAbi.abi, functionName: "balanceOf", args: [address],
  });
  return (
    <button onClick={() =>
      writeContract({ address: WSRX_ADDR, abi: wsrxAbi.abi, functionName: "deposit", value: parseEther("1") })
    }>Wrap 1 SRX → WSRX</button>
  );
}
```

## Multicall3

```ts
import multicallAbi from "@sentrix-labs/canonical-contracts/deployments/abi/Multicall3.json";

const calls = [
  { target: tokenA, callData: tokenAbi.encodeFunctionData("balanceOf", [user]) },
  { target: tokenB, callData: tokenAbi.encodeFunctionData("balanceOf", [user]) },
];
const ret = await multicall.aggregate(calls);
```

Use this anywhere you would on Ethereum mainnet — same Multicall3 ABI.

## TokenFactory

```ts
const factory = new ethers.Contract(deployments.TokenFactory.address, factoryAbi.abi, signer);
const tx = await factory.deployToken("My Token", "MTK", ethers.parseEther("1000000"));
const receipt = await tx.wait();
const event = receipt.logs.find(l => l.fragment?.name === "TokenDeployed");
const newTokenAddr = event.args.token;
```

## SentrixSafe

For programmatic Safe interaction, use `safe-core-sdk` patterns (Sentrix Safe is an interface-compatible fork). For UI: build with `safe-react` or wait for the official `safe.sentriscloud.com` UI (Tier 2 backlog).

## sentrix.js (native SDK)

Placeholder — TS SDK is on the Tier 2 ecosystem readiness roadmap. Once shipped:

```ts
import { Sentrix } from "@sentrix-labs/sentrix.js";

const client = new Sentrix({ network: "mainnet" });
await client.wsrx.deposit("1.0");           // wraps 1 SRX
await client.tokens.deploy({ name, symbol, supply });
```

The SDK will wrap both the EVM stack (eth_*) and the native stack (sentrix_*, REST).

## Native vs EVM token query

| Action | Native | EVM |
|---|---|---|
| Balance of native token (SRC-20 TokenOp) | `GET /tokens/{contract}/balance/{addr}` | — |
| Balance of EVM ERC-20 | — | `eth_call` `balanceOf(address)` |
| WSRX balance | — | `eth_call` `balanceOf` (WSRX is EVM ERC-20) |

Native TokenOp tokens (deployed via `POST /tokens/deploy`) are a separate contract surface from EVM tokens — see the dual-stack overview in [`sentrix/docs/architecture/EVM.md`](https://github.com/sentrix-labs/sentrix/blob/main/docs/architecture/EVM.md) and [`sentrix/docs/operations/SMART_CONTRACT_GUIDE.md`](https://github.com/sentrix-labs/sentrix/blob/main/docs/operations/SMART_CONTRACT_GUIDE.md) for the public reference. Token-standards comparison: [`sentrix/docs/tokenomics/TOKEN_STANDARDS.md`](https://github.com/sentrix-labs/sentrix/blob/main/docs/tokenomics/TOKEN_STANDARDS.md).
