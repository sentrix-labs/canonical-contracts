// Canonical contract ABI re-exports.
// Until forge build runs, the per-contract JSONs are placeholders.
// `npm run abi` (or `make abi`) refreshes them from the compiled artifacts.

module.exports = {
  WSRX: require("./WSRX.json"),
  Multicall3: require("./Multicall3.json"),
  SentrixSafe: require("./SentrixSafe.json"),
  TokenFactory: require("./TokenFactory.json"),
  FactoryToken: require("./FactoryToken.json"),
};
