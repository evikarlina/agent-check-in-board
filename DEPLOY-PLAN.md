# Deployment plan — AgentCheckIn on BNB Chain (BSC, chain 56)

Status: **NOT deployed.** This document records the verified route and costs
only. All chain reads below were done read-only on 2026-11-20 against
`https://bsc-dataseed.binance.org` (block 134,687,209).

## Why not a plain `baw contract-call` deployment?

`baw contract-call preview` requires a `--to` address — it sends a call to an
existing contract. A raw contract-creation transaction (no `to`) is therefore
**not supported** by the Agentic Wallet CLI. Deployment must go through an
on-chain deployer contract (Route A) or an external wallet (Route B).

## Route A (recommended): CREATE2 via the canonical deployer factory

The canonical deterministic-deployment proxy
**`0x4e59b44847b379578588920cA78FbF26c0B4956C`** was verified live on BSC:

- `eth_getCode` returns **69 bytes** of runtime code — the factory is deployed
  and present on BNB Chain. ✔

How it works: one `baw contract-call` to the factory with
`calldata = <32-byte salt> ++ <init code>` and value 0. The factory CREATE2-
deploys the init code and returns the new contract address. This fits
`AgentCheckIn` perfectly:

- The constructor takes only the Agent ID registry address
  (`0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F`) — it does **not** depend on
  `msg.sender`, so being deployed "by" the factory changes nothing.
- The contract has no owner/admin, so the factory being the deployer grants
  it no power over the contract.
- The resulting address is computable in advance:
  `keccak256(0xff ++ factory ++ salt ++ keccak256(initCode))[12:]`.

Flow when approved: build init code from the compiled artifact
(`out/AgentCheckIn.sol/AgentCheckIn.json`, creation bytecode ++ ABI-encoded
registry address) → `baw contract-call preview` (chain 56, to = factory,
value 0, inputData = salt ++ init code) → show the parsed preview to the user
→ explicit confirmation → `baw contract-call execute`. The user's wallet
signs and pays gas; every step keeps the normal confirmation flow.

## Cost estimate (measured, not guessed)

| Item | Value (2026-11-20) |
|---|---|
| Creation bytecode | 1,604 bytes |
| Deployed bytecode | 1,419 bytes |
| BSC gas price (`cast gas-price`) | 0.05 gwei (50,000,000 wei) |
| Estimated deployment gas | ≈ 400,000 gas (21k base + CREATE2 factory overhead + 200/byte code deposit + init execution + calldata) |
| Estimated cost | ≈ 0.00002 BNB |
| Wallet BSC balance (read-only) | **0.000215600523559821 BNB** |
| Headroom | ≈ 10× the estimate; even a 3× gas surprise stays affordable |

Per-check-in gas for users afterwards is small (the test suite's holder
check-in measured ~155k gas locally, ≈ 0.000008 BNB at 0.05 gwei).

## Route B: user deploys from their own wallet / Remix

The user deploys `AgentCheckIn` from any EVM wallet they control (e.g. Remix
+ MetaMask on BSC, constructor argument = the registry address above). We
then verify the deployed address on-chain (code matches the compiled
artifact, `registry()` returns the right address) and fill it into the
frontend. No Agentic Wallet involvement; gas paid by that wallet.

## BscScan verification (required by the hackathon rules)

After deployment, verify the source on BscScan so the contract is
open-source and verified:

```bash
forge verify-contract <DEPLOYED_ADDRESS> contracts/AgentCheckIn.sol:AgentCheckIn \
  --chain bsc --constructor-args <ABI-encoded registry address> \
  --etherscan-api-key <BSCSCAN_API_KEY>
```

(Equivalent: upload the standard-JSON input from `forge build` via BscScan's
"Verify & Publish" UI.) Compiler: solc 0.8.24, optimizer on, 200 runs — as
pinned in `foundry.toml`. Note for Route A: BscScan verification works the
same; the deployer being the CREATE2 factory does not affect verification.

## Hackathon submission checklist

Submission period ends **2026-12-09 08:00 UTC**. The submission needs:

- Project name (final name still to be confirmed — working name:
  "Agent Check-In Board"; must not impersonate the Binance brand)
- Website (the hosted `frontend/index.html`)
- Contract address(es) on BNB Chain — the deployed `AgentCheckIn`
- Agent ID usage description: Agent ID is the on-chain gate for the core
  write flow — `checkIn()` reverts unless `registry.balanceOf(msg.sender) > 0`
- Verified, open-source contract on BscScan (step above)
- Innovation Award eligibility additionally needs **≥ 30 distinct Agent ID
  addresses** interacting with the contract during the submission period —
  that is an outreach task after launch, not a code task.
