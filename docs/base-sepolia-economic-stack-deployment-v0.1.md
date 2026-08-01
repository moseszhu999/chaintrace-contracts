# Base Sepolia TradeProof Economic Stack Deployment v0.1

## Status

Deployment preparation only. This branch does not broadcast transactions.

The target is a public, source-reviewable Base Sepolia demonstration of the TradeProof economic architecture. It is not a public Token launch, sale, claim, liquidity event, mainnet release, financial product, or legal approval.

## Existing dependency

The stack reuses the canonical Base Sepolia `TradeProofRegistry`:

```text
Address: 0xad1c714140ceb8ed7c5234d939a06926f5edaba2
Chain ID: 84532
```

The deployment script rejects a zero or no-code Registry address.

## Target deployment topology

```text
existing TradeProofRegistry
        ↓
TradeProofContribution
        ↓
TradeProofSeasonAllocation

TradeProofGenesis
        ├─ TradeProofToken
        └─ TradeProofTeamVesting

Five explicit Testnet Treasury Vaults
        ├─ community 45%
        ├─ ecosystem 20%
        ├─ adoption 10%
        ├─ liquidity reserve 5%
        └─ security reserve 5%

Team beneficiary
        └─ immutable 15% vesting escrow
```

## Why testnet treasury vaults exist

`TradeProofGenesis` requires six distinct economic destinations. A production deployment should use separately reviewed treasury multisigs and timelocks. Those governance contracts do not yet exist.

For Base Sepolia only, the script deploys five visibly named `TradeProofTestnetTreasuryVault` contracts. Each vault:

- has an immutable operator;
- has an immutable purpose hash;
- can approve or transfer ERC-20 tokens only when the operator explicitly acts;
- cannot change operator;
- cannot upgrade;
- has no ETH receive or sweep function;
- is explicitly unsuitable for production custody.

The testnet operator is also the immutable team beneficiary and seasonal-allocation publisher. This centralization is disclosed and is not a production governance model.

## Script inputs

The Foundry script reads only public deployment configuration:

```text
TRADE_PROOF_REGISTRY
TESTNET_OPERATOR
```

The signing key is supplied to the Foundry command or CI secret mechanism, not read or logged by the Solidity script.

Expected command shape:

```bash
TRADE_PROOF_REGISTRY=0xad1c714140ceb8ed7c5234d939a06926f5edaba2 \
TESTNET_OPERATOR=0x... \
forge script script/DeployTradeProofEconomicStack.s.sol:DeployTradeProofEconomicStack \
  --rpc-url https://sepolia.base.org \
  --private-key "$DEPLOYER_PRIVATE_KEY" \
  --broadcast
```

The private key must never appear in source, logs, comments, artifacts, manifests, screenshots, or chat.

## Atomic post-deployment invariants

The script verifies:

- total Token supply equals 1,000,000,000 TPROOF;
- community vault holds exactly 450,000,000;
- ecosystem vault holds exactly 200,000,000;
- team vesting holds exactly 150,000,000;
- adoption vault holds exactly 100,000,000;
- liquidity reserve holds exactly 50,000,000;
- security reserve holds exactly 50,000,000;
- Genesis factory holds zero tokens.

## Deliberately inactive after deployment

A successful testnet deployment leaves:

```text
season proposal: none
season funding: zero
claim root: none
claim active: false
community vault allowance to allocation: zero
liquidity pool: none
sale: none
market: none
```

No user can claim TPROOF merely because the contracts exist.

## Required deployment evidence

A canonical deployment manifest must record:

- exact source commit;
- operator public address;
- every contract address;
- transaction hashes;
- block range and deployment time;
- code-length checks;
- fixed supply and exact balances;
- Contribution Registry reference;
- Allocation Token, Contribution, publisher, and community-treasury references;
- inactive distribution state;
- testnet-only and no-launch boundaries.

The template is:

```text
deployments/base-sepolia-economic-stack.template.json
```

A real manifest must be produced only after a successful broadcast and independent chain reads.

## Gates before broadcast

- exact implementation source is merged to `main`;
- Foundry formatting/build/tests pass;
- DLSK reports zero HIGH and CRITICAL findings;
- deployment simulation passes on chain ID 84532;
- operator address derived from the secret matches `TESTNET_OPERATOR`;
- Registry code and exact address are verified;
- deployer has enough Base Sepolia ETH;
- one deployment job is active, with nonce and duplicate-deployment protection.

## Gates not satisfied by testnet deployment

A successful Base Sepolia transaction does not satisfy:

- external smart-contract audit;
- production multisig/timelock governance;
- canonical Season 0 eligibility and anti-Sybil review;
- public-claim authorization;
- legal review for any jurisdiction;
- mainnet deployment authorization;
- sale, liquidity, exchange listing, or price communication authorization.
