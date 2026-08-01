# TradeProof Seasonal Allocation v0.1

## Status

Bounded implementation for source review and testnet preparation.

No seasonal distribution is deployed, funded, activated, or claimable by this document or its implementation branch. TPROOF remains not live.

## Purpose

Convert a closed season of non-transferable Proof Points into a publicly auditable TPROOF distribution without requiring a private application database.

```text
closed onchain Proof Points
→ public deterministic allocation dataset
→ square-root reward calculation
→ dataset digest + Merkle root
→ seven-day review delay
→ fully funded immutable distribution
→ wallet or relayer submits Merkle proof
→ contract rechecks final onchain Points
→ exact TPROOF transfer
```

## Canonical economic source

```text
moseszhu999/trade-proof-passport
standard/tproof-token-economics-v0.1.md
tokenomics/tproof-tokenomics-v0.1.json
```

Fixed parameters implemented here:

```text
reward profile: TPROOF_SQRT_VERIFIED_POINTS_V0_1
minimum eligibility: 25 Points
claim delay after proposal: 7 days
Season 0 pool: 10,000,000 TPROOF
maximum aggregate community commitment: 450,000,000 TPROOF
```

## Why calculation is offchain

For eligible wallets `i`, the economic formula is:

```text
weight_i = sqrt(verifiedPoints_i)
reward_i = seasonPool × weight_i / sum(all eligible weights)
```

Recomputing every square root and global denominator in each claim would require iterating over the whole contributor set onchain. Instead:

1. all closed-season Points are public contract state and events;
2. a deterministic tool or browser reads that public state;
3. it publishes the full input, rounding policy, weights, denominator, rewards, and sum;
4. the canonical JSON dataset is hashed;
5. claim leaves are placed in a sorted-pair Merkle tree;
6. the dataset digest and root are proposed onchain;
7. the seven-day delay allows independent recomputation before activation.

The contract does **not** claim that publishing authority alone proves the formula was followed. Formula correctness is established by reproducible public data and independent recomputation. The contract enforces the fixed root after activation and verifies each leaf against final onchain Points.

## Public dataset shape

A future canonical dataset should include at least:

```json
{
  "format": "tradeproof-season-allocation",
  "version": "0.1",
  "chainId": 84532,
  "allocationContract": "0x...",
  "contributionContract": "0x...",
  "tokenContract": "0x...",
  "season": 0,
  "revision": 1,
  "rewardProfile": "TPROOF_SQRT_VERIFIED_POINTS_V0_1",
  "poolAmountBaseUnits": "10000000000000000000000000",
  "minimumEligibilityPoints": 25,
  "rounding": "floor-each-leaf-remainder-policy-published",
  "entries": [
    {
      "account": "0x...",
      "verifiedPoints": "100",
      "sqrtWeight": "...",
      "tokenAmountBaseUnits": "...",
      "leaf": "0x..."
    }
  ],
  "totalAllocatedBaseUnits": "10000000000000000000000000",
  "merkleRoot": "0x..."
}
```

The exact canonical JSON profile and rounding/remainder rule must be published and machine-tested before any claim activation. No private source document belongs in the dataset.

## Claim leaf

Each leaf is domain-separated by chain, contract, season, and proposal revision:

```text
keccak256(abi.encode(
  CLAIM_TYPEHASH,
  chainId,
  allocationContract,
  season,
  revision,
  account,
  verifiedPoints,
  tokenAmount
))
```

The Merkle tree uses sorted pair hashing:

```text
keccak256(min(left,right) || max(left,right))
```

This prevents a proof from being reused across another chain, allocation contract, season, revision, account, Points snapshot, or amount.

## Lifecycle

### 1. Close the contribution season

`TradeProofContribution.seasonClosed(season)` must be true. Closing occurs only after its review and appeal windows.

### 2. Propose

The immutable publisher supplies:

- Merkle root;
- canonical dataset digest;
- leaf count;
- total allocation.

Season 0 must equal exactly 10,000,000 TPROOF. Every proposal emits the fixed reward profile hash and a seven-day `claimableAt` time.

A proposal can be cancelled before activation with a public reason hash. Any funding is returned to the immutable community treasury. Republishing increments the season revision, which changes every claim leaf.

### 3. Fund

The publisher triggers an exact `transferFrom` from the immutable community treasury after treasury approval.

The contract tracks aggregate community commitments and refuses to exceed 450,000,000 TPROOF.

Direct, unsolicited Token transfers are not counted as season funding and should not be sent to the contract.

### 4. Activate

Anyone may activate after:

- the seven-day review delay;
- exact full funding.

After activation the root cannot be cancelled, replaced, swept, or rewritten.

### 5. Claim

A claimant or relayer submits:

- season;
- destination account;
- final verified Points snapshot;
- Token amount;
- Merkle proof.

The contract checks:

- distribution is active;
- wallet has not claimed;
- final onchain Points are at least 25;
- supplied Points exactly match the closed-season contract state;
- proof matches the activated root;
- cumulative claims do not exceed the published total.

Tokens always go to the leaf account, never the relayer.

## Trust and governance boundary

The publisher is immutable for a deployed allocation contract. Production deployment should set it to the reviewed treasury timelock or governed publishing contract, not an undisclosed hot wallet.

The publisher may propose, fund, and cancel **before activation**. It cannot:

- rewrite an active root;
- change a wallet's Contribution Points;
- mark a wallet claimed;
- redirect a valid claim;
- sweep active claim funds;
- mint TPROOF;
- validate a Passport or Response;
- rewrite Registry history.

Because v0.1 has no claim expiry or sweep, unclaimed active funds remain reserved. Any future expiry/recovery design requires a separate economic and governance review.

## Explicit non-capabilities

The contract does not:

- calculate the global square-root dataset onchain;
- hide or store a private eligibility database;
- create contribution receipts or Points;
- mint or burn TPROOF;
- create a sale, price, pool, market, yield, dividend, or redemption;
- transfer trade goods, invoices, receivables, payments, or other real-world assets;
- verify identity, employment, or organizational authority;
- make a trade assertion true.

## Required work before activation

- canonical allocation JSON and rounding profile;
- deterministic browser/CLI compiler and independent vectors;
- source-verified testnet deployments;
- external smart-contract review;
- published Genesis anti-Sybil and appeal results;
- treasury multisig, signer, and timelock policy;
- legal review before any public claim, offer, or trading action;
- community approval of final parameters.
