# ChainTrace Contracts

**Canonical Solidity contracts for the TradeProof proof and contributor economy.**

## Canonical contract stack

```text
TradeProofRegistry
  Passport / Response digest chronology and current state
        ↓
TradeProofContribution
  non-transferable contribution receipts and seasonal Proof Points
        ↓
TradeProofSeasonAllocation
  closed Points → public Merkle dataset → delayed TPROOF claims
        ↓
TradeProofGenesis
  atomic fixed-supply Token and team-vesting deployment
        ├─ TradeProofToken
        └─ TradeProofTeamVesting
```

Token holdings, transfers, claims, allowances, vesting, receipts, or Proof Points can never make a Passport, Response, evidence record, or real-world assertion valid.

## TradeProofRegistry

`TradeProofRegistry` anchors canonical Passport and Response digests with issuer, timestamp, schema/profile hashes, supersession links, revocation state, and Response subject continuity.

It does not store source documents or commercial plaintext.

```text
docs/trade-proof-registry-v0.1.md
```

## TradeProofContribution

`TradeProofContribution` records non-transferable receipts and seasonal Proof Points derived from current Registry anchors and governed public-goods review.

Automatic contribution classes:

```text
unique Passport                          +5 issuer
independent external Response            +10 Passport issuer / +20 responder
third distinct responder role            +30 Passport issuer
viral reuse within 30 days               +50 inviter / +25 creator
repeat use across two lineages           +20 participant
```

Reviewed public-goods ranges:

```text
accepted standard change                    500–3,000
production connector or Agent integration 1,500–10,000
security finding or fix                     500–15,000
verified repeat adoption case             1,000–10,000
documentation, translation, or education    100–2,000
```

Controls:

```text
season length                              90 days
receipt review delay                       30 days
appeal window                              14 days
viral reuse window                         30 days
minimum eligibility                        25 points
automatic wallet/day cap                  200 points
automatic wallet-pair/season cap          300 points
```

```text
docs/trade-proof-contribution-v0.1.md
```

## TradeProofSeasonAllocation

`TradeProofSeasonAllocation` connects closed Proof Points to pre-funded TPROOF claims without a private application database.

```text
closed public Points
→ deterministic square-root allocation dataset
→ canonical dataset digest + sorted Merkle root
→ seven-day public review delay
→ exact funding from immutable community treasury
→ immutable active root
→ wallet or relayer submits proof
→ final Points checked against TradeProofContribution
→ exact Token transfer to leaf account
```

Fixed controls:

```text
minimum claim eligibility                   25 Points
claim delay                                  7 days
Season 0 Genesis Proof pool         10,000,000 TPROOF
aggregate community commitment cap 450,000,000 TPROOF
reward profile              TPROOF_SQRT_VERIFIED_POINTS_V0_1
```

Claim leaves are domain-separated by chain ID, allocation contract, season, revision, account, final Points, and amount. A proposed distribution can be cancelled and refunded only before activation. An active root cannot be rewritten, cancelled, or swept.

The contract verifies Merkle inclusion and the final closed-season Points snapshot. The global square-root calculation remains reproducible public computation and must be independently recomputed from the published dataset before activation.

```text
docs/trade-proof-season-allocation-v0.1.md
```

## Fixed-supply TPROOF genesis

### TradeProofToken

```text
Name: TradeProof Token
Symbol: TPROOF
Decimals: 18
Maximum supply: 1,000,000,000
Genesis supply: 1,000,000,000
Post-genesis minting: none
Owner/admin role: none
Transfer tax: none
Forced transfer: none
Proxy/upgrade path: none
```

Exact constructor allocation:

```text
Community contributions              450,000,000  45%
Ecosystem and developer fund         200,000,000  20%
Core team vesting                    150,000,000  15%
Real adoption incentives             100,000,000  10%
Liquidity bootstrapping reserve       50,000,000   5%
Security and standards reserve        50,000,000   5%
                                    -----------
                                  1,000,000,000 100%
```

The liquidity reserve is only an allocation bucket. No pool, sale, price, market, claim, or trading venue is created by Token genesis.

### TradeProofTeamVesting

```text
allocation: 150,000,000 TPROOF
cliff: 365 days
linear vesting duration: 1,460 days
beneficiary: immutable
start timestamp: immutable and cannot be backdated
administrator: none
```

At the 12-month cliff, 25% is vested. Anyone may trigger a release, but vested tokens only reach the immutable beneficiary.

### TradeProofGenesis

The atomic genesis factory validates six distinct recipients, deploys the Token and vesting escrow, transfers all 150,000,000 team tokens into vesting, verifies exact supply and balances, retains zero Token balance, and exposes no post-deployment control function.

```text
docs/trade-proof-token-genesis-v0.1.md
```

The economic constitution remains canonical in:

```text
https://github.com/moseszhu999/trade-proof-passport/blob/main/standard/tproof-token-economics-v0.1.md
https://github.com/moseszhu999/trade-proof-passport/blob/main/tokenomics/tproof-tokenomics-v0.1.json
```

## Canonical Base Sepolia Registry deployment

```text
Network: Base Sepolia
Chain ID: 84532
Contract: TradeProofRegistry
Address: 0xad1c714140ceb8ed7c5234d939a06926f5edaba2
Transaction: 0x6ffcae50367e9087c736ff5c7edd7d30483aedb0e8082488a0d8a8784cbdd31c
Block: 44891502
Deployer: 0x072A01FE3DdbF351DAaf6Da70CE5E67f5101fEC9
Reviewed source: 27248faeed7f3eb88428fa8ce7979223e088429f
Deployed bytecode: 2433 bytes
Bytecode check: PASS
Explorer source verification: pending
```

```text
deployments/base-sepolia.json
```

The Registry remains an independently deployed proof primitive. Its evidence validity and current-state rules do not depend on TPROOF, Proof Points, claims, or treasury balances.

## Canonical Base Sepolia economic-stack deployment

The bounded testnet economic stack was deployed from reviewed source commit:

```text
005839c62c1a67392b2f5cced25374f5b48fecc1
```

Deployment status:

```text
Network: Base Sepolia
Chain ID: 84532
Operator: 0x072A01FE3DdbF351DAaf6Da70CE5E67f5101fEC9
Transactions: 8
Operator nonce: 2 → 10
Block range: 44901311–44901318
Bytecode checks: PASS
Status: deployed-testnet-inactive
Explorer source verification: pending
```

Canonical addresses:

```text
TradeProofContribution:         0xcb33eA69dDa48f2A345Fc1F2A3B85f329a5eb1E0
TradeProofGenesis:              0x2a00707664d738d41EDc4e453F173D38f6D83ECb
TradeProofToken:                0xd0a60427482C2cBE1C6566772DC5838AA06DED80
TradeProofTeamVesting:          0x65Ab9CE997975f18b6a06957D75AA5a00b3dc467
TradeProofSeasonAllocation:     0x0bFd6CEab5dB51d7B53789484ECD147B10D7fC65
Community treasury:             0xBf485863EA313b75dC6cf389A9A86Bd98a0dF910
Ecosystem treasury:             0x3Ca8dd7dF625d51aF1Da77716269D788DD869089
Adoption treasury:              0x895C0C8749EF5DE94BA544cf28dDEd68fd6b3Aba
Liquidity reserve:              0xC7F135d85aAe58bd409F7263FadbD041d6031B92
Security reserve:               0x594ce0619d5bAcA2F66992c89610cb57A704d0AB
```

Canonical machine-readable evidence:

```text
deployments/base-sepolia-economic-stack.json
```

The deployment and a later read-only recovery gate verified all eight receipts, all ten deployed bytecodes, the fixed 1,000,000,000 TPROOF supply, exact 45/20/15/10/5/5 allocations, Registry and contract references, five vault purpose hashes, and the inactive initial state.

The current deployment does **not** authorize or activate:

```text
Season 0 proposal or funding
public TPROOF claim
Token sale, presale, auction, or price
liquidity pool or market
mainnet deployment
production governance
```

The five testnet vaults and single testnet operator are explicitly not a production governance design.

## Legacy proof primitives

```text
contracts/ProofRegistry.sol
contracts/BatchRegistry.sol
contracts/EventRegistry.sol
```

These are retained historical primitives, not competing Passport, contribution, Token, or allocation owners.

## Current implementation scope

Implemented in source and Base Sepolia testnet deployment:

- Passport and Response digest anchoring;
- supersession and revocation history;
- contribution receipts and seasonal Proof Points;
- automatic and reviewed contribution classes;
- anti-wash caps, review delay, appeals, revocation, and season closure;
- fixed one-billion TPROOF supply;
- exact six-bucket genesis allocation;
- immutable team cliff and linear vesting;
- atomic genesis invariant checks;
- closed-season Merkle proposal, funding, delay, activation, and claim verification;
- Points snapshot checks and one claim per wallet;
- Season 0 exact 10,000,000 TPROOF pool;
- aggregate 450,000,000 community commitment ceiling;
- canonical Base Sepolia Registry and inactive economic-stack deployments;
- machine-readable deployment evidence and bytecode checks;
- Foundry and DLSK CI gates.

Not implemented or authorized:

- active public claim or Genesis Proof distribution;
- canonical allocation dataset compiler and rounding profile;
- sale, presale, auction, pricing, or liquidity action;
- staking yield, revenue share, dividend, or redemption;
- governance execution;
- production multisig or timelock;
- claim expiry or active-fund sweep;
- payment, settlement, lending, custody, or asset tokenization;
- identity or organizational-authority verification;
- production or mainnet deployment of the economic stack;
- formal external smart-contract audit;
- legal launch clearance.

## Local validation

```bash
forge fmt --check
forge build --sizes
forge test -vvv
```

Pull requests also run DLSK and block any HIGH or CRITICAL finding. DLSK and Foundry are pre-audit gates, not a formal external audit.

## Design principles

```text
Proof, not exposure.
Contribution before liquidity.
Public allocation data, not a private eligibility database.
Fixed supply, no hidden mint.
Long vesting, no instant team unlock.
Immutable active roots, no silent claim rewrite.
Community economics, not control of evidence validity.
No public launch before technical, security, governance, and legal gates.
```

## License

MIT.

## Disclaimer

These contracts are experimental and unaudited. They do not constitute a financial product, investment contract, token sale, lending system, payment system, legal attestation, or promise of price, liquidity, yield, revenue share, redemption, or future returns.
