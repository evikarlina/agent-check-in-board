# Agent Check-In Board

*Working name — final name to be confirmed before submission.*

A daily check-in + guestbook dApp for **Binance Agent ID** holders, deployed on
BNB Chain (BSC, chain 56). Built for the Binance Agent ID Hackathon
(submission period 2026-11-18 → 2026-12-09 08:00 UTC).

## What it is

Every day, an address that holds an Agent ID can "check in" once on-chain,
optionally leaving a short public note (a guestbook entry). The contract
tracks each agent's current streak, best streak, and total check-ins, plus
global counters (unique agents, total check-ins). A single static web page
shows the public stats and lets a holder check in from their own wallet.

There are no tokens, no rewards, and no asset movement of any kind — the
check-in *is* the product: a lightweight, recurring, identity-gated on-chain
ritual that only Agent ID holders can perform.

## How Agent ID is used (core flow, not a bolt-on)

Agent ID is the access key for the dApp's only write function:

1. The user connects a browser wallet on the frontend.
2. The frontend reads the Agent ID registry
   (`0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F`, SPACE ID Agent ID, ERC-721
   soulbound) — `balanceOf(connectedAddress) > 0` means "holds an Agent ID".
3. On check-in, the **contract itself** repeats that check for `msg.sender`
   and reverts for non-holders. The gate is enforced on-chain, so it cannot
   be bypassed by a modified frontend.
4. One check-in per address per UTC day; streaks reward returning agents.

## Contract

`contracts/AgentCheckIn.sol` — Solidity 0.8.24, Foundry project.

- `checkIn(string note)` — holder-only, once per UTC day; note (≤140 bytes)
  is emitted in the `CheckedIn` event only, never stored.
- `statsOf(address)`, `totalAgents()`, `totalCheckIns()`, `isAgent(address)` — views.

### Permissions statement

**The contract has no owner and no admin functions.** Specifically:

- No payable functions; the contract never receives, holds, or moves assets.
- No token approvals, no transfers, no `onlyOwner` anything.
- The Agent ID registry address is set once in the constructor and is
  `immutable` — it cannot be changed after deployment.
- Nobody, including the deployer, can pause, upgrade, or alter the contract.

## Tests

```bash
export PATH="$HOME/workspace/tools/foundry-1.7.1:$PATH"
forge build
forge test
```

8 tests cover: non-holder rejection, holder check-in, same-day double
check-in rejection, consecutive-day streak increments, streak reset after a
gap, unique-agent/total counters across agents, the 140-byte note limit, and
the `isAgent` view. The registry is mocked with a minimal stub
(`test/AgentCheckIn.t.sol`).

## Frontend

`frontend/index.html` is a single static file (ethers v6 via CDN, no backend,
no accounts, no login sessions, no QR/pairing-code login of any kind — users
connect their own browser wallet and confirm every transaction themselves).

Serve it with any static host, e.g.:

```bash
cd frontend && python3 -m http.server 8080
```

Before going live, set `CONTRACT_ADDRESS` at the top of the inline script to
the deployed `AgentCheckIn` address (see `DEPLOY-PLAN.md`).

## License

MIT — see [LICENSE](LICENSE).

## Deployment (BSC mainnet)

- Contract: `0x9ea81607a0f6fa796b2432308f9190c860b70205`
- Deployed 2026-11-20 via the canonical CREATE2 factory `0x4e59b44847b379578588920cA78FbF26c0B4956C` from the Agentic Wallet `0xf76245443983eCf6FfbA1e34c892D0EcFDB86f8D`
- Tx: `0x338ebeb0838e5c787c0c7018ec6b12ed5bc6d19746e56caa2bcc71b4cbc33c37` (block 134,689,390, gas used 363,325)
- Registry (immutable): `0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F`
