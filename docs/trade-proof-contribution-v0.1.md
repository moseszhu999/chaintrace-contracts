# TradeProofContribution v0.1

## Status

Bounded testnet implementation for non-transferable contribution receipts and seasonal Proof Points.

This contract does **not** mint, transfer, distribute, sell, or price TPROOF. It cannot alter whether a Trade Proof Passport or Response is valid, current, revoked, or superseded.

## Canonical economic source

The implementation is derived from:

```text
moseszhu999/trade-proof-passport
standard/tproof-token-economics-v0.1.md
tokenomics/tproof-tokenomics-v0.1.json
```

The Token Economics source remains the economic constitution. This contract implements the contribution-accounting subset only.

## Architecture

```text
TradeProofRegistry
  current Passport / Response anchors
            ↓
TradeProofContribution
  pending non-transferable receipts
  reviewer exclusion / appeal
  delayed finalization
  seasonal verified Proof Points
            ↓ future, not implemented here
season allocation / TradeProofToken
```

## Economic assets implemented

### Contribution Receipt

A receipt records:

- beneficiary wallet;
- automatic-usage or reviewed-public-goods track;
- contribution kind;
- Passport, Response, or evidence digest references;
- recorded season and timestamps;
- requested and approved points;
- reviewer decision, exclusion, appeal, finalization, or revocation state.

A receipt is a contract record, not an ERC-20 or ERC-721 asset. It has no transfer function.

### Proof Points

Finalized receipts add non-transferable points to:

```text
verifiedPoints[season][beneficiary]
totalVerifiedPoints[season]
```

Points are accounting inputs for a future seasonal allocation process. They are not TPROOF and have no onchain transfer or redemption path in v0.1.

## Fixed timing and caps

```text
Season length:                         90 days
Receipt review delay:                 30 days
Appeal window:                        14 days
Future claim delay parameter:          7 days
Viral reuse window:                   30 days
Minimum season eligibility:           25 points
Automatic wallet/day cap:            200 points
Automatic wallet-pair/season cap:    300 points
```

## Automatic usage track

### Unique Passport

A current Passport issuer may record:

```text
issuer: +5 points
```

Duplicate receipt creation is rejected.

### Independent external Response

For a current Response whose issuer differs from the current Passport issuer:

```text
Passport issuer: +10 points
Response issuer: +20 points
```

Self-responses are rejected and earn zero.

### Third distinct responder role

Three current Responses must:

- reference the same current Passport;
- have three distinct responder wallets;
- have three distinct nonzero self-declared role hashes;
- differ from the Passport issuer.

The Passport issuer receives:

```text
+30 points
```

Role hashes are self-declared. The contract does not verify employment, authority, or organizational identity.

### Viral reuse

A Response issuer who anchors a distinct current Passport within 30 days creates:

```text
original Passport issuer: +50 points
new Passport creator:     +25 points
```

The original Passport issuer and responder must differ.

### Repeat trade usage

An actor participating as issuer or responder in two distinct Passport lineages, each with an independent Response in the same or adjacent season, receives:

```text
+20 points
```

## Reviewed public-goods track

A contributor may submit an evidence digest and requested points within the canonical class range:

```text
accepted standard change:                    500–3,000
production connector or Agent integration: 1,500–10,000
security finding or fix:                     500–15,000
verified repeat adoption case:             1,000–10,000
documentation, translation, or education:    100–2,000
```

An authorized reviewer may approve a bounded amount or reject the submission. Approved contributions enter the same 30-day delay before finalization.

## Review, appeal, and revocation

- Pending receipts may be excluded with a reason hash.
- The beneficiary may appeal an excluded receipt within 14 days.
- A reviewer may restore the receipt to a new delayed-review period.
- A finalized receipt may be revoked before season closure; its verified points are subtracted.
- A closed season freezes its finalized accounting history.

The initial owner/reviewer is the deployment account. This is a bounded testnet control surface. Production governance requires the published multisig, signer, timelock, conflict, review, and appeal policies before launch.

## Explicit non-capabilities

The contract does not:

- mint or transfer TPROOF;
- calculate the square-root seasonal Token allocation;
- activate a claim;
- hold a Token treasury;
- create a public sale or liquidity pool;
- verify legal identity or organizational authority;
- inspect private Passport or Response content;
- prove that a trade assertion is true;
- modify TradeProofRegistry history or current state;
- provide ownership of goods, invoices, receivables, payments, or other real-world assets.

## Audit posture

Foundry tests and DLSK are pre-audit checks. They are not an independent external security review. A testnet deployment does not satisfy the Token launch gates by itself.
