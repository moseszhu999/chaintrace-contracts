# Local Development

This repository currently uses Foundry for lightweight Solidity development.

## Install Foundry

Follow the official Foundry installation guide for your operating system.

## Compile

```bash
forge build
```

## Format

```bash
forge fmt
```

## Suggested First Local Test

After cloning the repository, run:

```bash
git clone https://github.com/moseszhu999/chaintrace-contracts.git
cd chaintrace-contracts
forge build
```

## Current Contract Set

```text
contracts/ProofRegistry.sol
contracts/BatchRegistry.sol
contracts/EventRegistry.sol
```

## Next Contract Milestone

The next milestone is to connect `ProofRegistry` to the front-end app:

```text
chaintrace-app
        ↓
calculate SHA-256 file hash
        ↓
call ProofRegistry.registerProof
        ↓
return proofId and transaction hash
        ↓
show transaction hash on Proof Page
```
