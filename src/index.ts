// Public entry point for @sentrix-labs/canonical-contracts.
//
// Two consumption paths:
//
//   import { WSRX, getAddress } from "@sentrix-labs/canonical-contracts";
//   const w = createPublicClient({ chain, transport: http() });
//   const sym = await w.readContract({
//     address: getAddress("WSRX", 7119),
//     abi: WSRX.abi,
//     functionName: "symbol",
//   });
//
// Or if you just want the ABI const for typed event filters / encoding:
//
//   import { WSRX_ABI } from "@sentrix-labs/canonical-contracts";
//
// All ABIs are emitted with `as const` so viem (and any other tooling
// that reads the literal type) can derive precise argument + return
// types per function — no codegen step needed on the consumer side.

export {
  WSRX,
  WSRX_ABI,
  type WSRXAddress,
  Multicall3,
  Multicall3_ABI,
  type Multicall3Address,
  SentrixSafe,
  SentrixSafe_ABI,
  type SentrixSafeAddress,
  TokenFactory,
  TokenFactory_ABI,
  type TokenFactoryAddress,
  FactoryToken,
  FactoryToken_ABI,
  type FactoryTokenAddress,
  CONTRACTS,
  CHAIN_IDS,
  type ChainId,
  getAddress,
} from "./generated.js";
