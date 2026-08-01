# ChainTrace Contracts

**Minimal smart contracts for the Trade Proof and ChainTrace proof layer.**

This repository is the canonical Solidity source of truth for Trade Proof contracts.

## Canonical v0.1 contract

### TradeProofRegistry.sol

`TradeProofRegistry` anchors canonical digests of:

- Trade Proof Passports;
- Trade Proof Responses.

It records:

- issuer wallet;
- block timestamp;
- artifact kind;
- Passport subject for a Response;
- schema hash;
- digest profile hash;
- supersession links;
- revocation state and reason hash.

It does not store source documents or commercial plaintext.

The initial digest profile is documented in:

```text
docs/trade-proof-registry-v0.1.md
```

## Legacy proof primitives

The following contracts are retained as early ChainTrace proof primitives:

```text
contracts/ProofRegistry.sol
contracts/BatchRegistry.sol
contracts/EventRegistry.sol
```

They are not the canonical Trade Proof Passport registry and should not be extended into a competing Passport/version/revocation system.

- `ProofRegistry` anchors individual evidence-file hashes and references.
- `BatchRegistry` creates simple batch/order/shipment keys.
- `EventRegistry` records simple supply-chain event references.

Future compatibility work may map these legacy objects into Trade Proof Passport evidence and fact profiles.

## Contract architecture

```text
Trade Proof Passport / Response JSON
        ↓ canonicalization profile
Keccak-256 artifact digest
        ↓
TradeProofRegistry
        ↓
issuer + timestamp + schema/profile + lifecycle links
```

Evidence documents remain off-chain. Evidence-level SHA-256 hashes inside a Passport are distinct from the canonical Passport or Response digest anchored by `TradeProofRegistry`.

## Current scope

Implemented:

- Passport digest anchoring;
- Response digest anchoring against a current Passport;
- same-issuer version supersession;
- Response subject continuity;
- issuer-controlled revocation;
- current/history queries;
- Foundry tests;
- Base Sepolia deployment script;
- Foundry and DLSK CI gates.

Not implemented yet:

- `TradeProofContribution.sol`;
- `TradeProofToken.sol`;
- token issuance or distribution;
- contribution rewards;
- payment or settlement;
- lending or disbursement;
- custody;
- asset tokenization;
- production identity or organizational-authority verification.

## Local development

Install Foundry and run:

```bash
forge fmt --check
forge build
forge test -vvv
```

## Base Sepolia deployment

Set environment variables locally without committing a private key:

```bash
export BASE_SEPOLIA_RPC_URL="..."
export DEPLOYER_PRIVATE_KEY="..."
```

Simulate first:

```bash
forge script script/DeployTradeProofRegistry.s.sol:DeployTradeProofRegistry \
  --rpc-url base_sepolia
```

Broadcast only after review:

```bash
forge script script/DeployTradeProofRegistry.s.sol:DeployTradeProofRegistry \
  --rpc-url base_sepolia \
  --broadcast
```

After deployment, replace the template values in a reviewed deployment manifest derived from:

```text
deployments/base-sepolia.example.json
```

No deployment is represented as complete until the address, transaction, block, source commit, and explorer-verification state are recorded.

## Security gate

Pull requests run:

```text
forge fmt --check
forge build --sizes
forge test -vvv
DLSK scan with fail-on-high
```

DLSK is a pre-audit readiness gate, not a formal security audit.

## Design principles

```text
Proof, not exposure.
Hashes, not sensitive files.
Portable objects, not platform lock-in.
Evidence integrity, not automatic truth.
Community incentives, not control of evidence validity.
```

## License

MIT.

## Disclaimer

These contracts are experimental and unaudited. They do not constitute a financial product, investment contract, token sale, lending system, payment system, legal attestation, or promise of future returns.
