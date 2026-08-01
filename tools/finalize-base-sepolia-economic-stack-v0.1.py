#!/usr/bin/env python3
"""Verify and render canonical Base Sepolia economic-stack deployment evidence.

This tool never reads a private key and never sends a transaction. It consumes a
Foundry broadcast file after the guarded deployment job has completed.
"""

from __future__ import annotations

import json
import os
import subprocess
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

EXPECTED_SOURCE = "005839c62c1a67392b2f5cced25374f5b48fecc1"
EXPECTED_REGISTRY = "0xad1c714140ceb8ed7c5234d939a06926f5edaba2"
EXPECTED_OPERATOR = "0x072A01FE3DdbF351DAaf6Da70CE5E67f5101fEC9"
EXPECTED_NONCE_BEFORE = 2
EXPECTED_NONCE_AFTER = 10
EXPECTED_TX_COUNT = 8
EXPECTED_TOTAL_SUPPLY = 1_000_000_000 * 10**18

PURPOSES = (
    "TPROOF_TESTNET_COMMUNITY",
    "TPROOF_TESTNET_ECOSYSTEM",
    "TPROOF_TESTNET_ADOPTION",
    "TPROOF_TESTNET_LIQUIDITY_RESERVE",
    "TPROOF_TESTNET_SECURITY_RESERVE",
)

BALANCES = {
    "communityTreasury": 450_000_000 * 10**18,
    "ecosystemTreasury": 200_000_000 * 10**18,
    "teamVesting": 150_000_000 * 10**18,
    "adoptionTreasury": 100_000_000 * 10**18,
    "liquidityReserve": 50_000_000 * 10**18,
    "securityReserve": 50_000_000 * 10**18,
}


def require_env(name: str) -> str:
    value = os.environ.get(name, "").strip()
    if not value:
        raise SystemExit(f"Missing required environment variable: {name}")
    return value


def command(*args: str) -> str:
    return subprocess.check_output(args, text=True).strip()


def first_token(value: str) -> str:
    tokens = value.split()
    if not tokens:
        raise SystemExit("Empty cast response")
    return tokens[0]


def cast_call(rpc_url: str, address: str, signature: str, *args: str) -> str:
    return first_token(command("cast", "call", address, signature, *args, "--rpc-url", rpc_url))


def normalized(address: str) -> str:
    value = address.strip().lower()
    if not value.startswith("0x") or len(value) != 42:
        raise SystemExit(f"Invalid address: {address}")
    return value


def parse_int(value: Any) -> int:
    if isinstance(value, int):
        return value
    text = str(value)
    return int(text, 16) if text.startswith("0x") else int(text)


def assert_equal(actual: Any, expected: Any, label: str) -> None:
    if actual != expected:
        raise SystemExit(f"{label}: expected {expected!r}, received {actual!r}")


def main() -> None:
    rpc_url = require_env("BASE_SEPOLIA_RPC_URL")
    source_commit = require_env("SOURCE_COMMIT")
    operator = require_env("DEPLOYER_ADDRESS")
    balance_before = require_env("DEPLOYER_BALANCE_BEFORE")
    nonce_before = int(require_env("DEPLOYER_NONCE_BEFORE"))
    broadcast_path = Path(require_env("BROADCAST_FILE"))

    assert_equal(source_commit, EXPECTED_SOURCE, "source commit")
    assert_equal(normalized(operator), normalized(EXPECTED_OPERATOR), "operator")
    assert_equal(nonce_before, EXPECTED_NONCE_BEFORE, "operator nonce before")

    data = json.loads(broadcast_path.read_text(encoding="utf-8"))
    creates = [
        item
        for item in data.get("transactions", [])
        if item.get("transactionType") in {"CREATE", "CREATE2"}
        and item.get("contractAddress")
    ]
    if len(creates) != EXPECTED_TX_COUNT:
        raise SystemExit(f"Expected {EXPECTED_TX_COUNT} top-level creates, found {len(creates)}")

    expected_names = [
        "TradeProofTestnetTreasuryVault",
        "TradeProofTestnetTreasuryVault",
        "TradeProofTestnetTreasuryVault",
        "TradeProofTestnetTreasuryVault",
        "TradeProofTestnetTreasuryVault",
        "TradeProofContribution",
        "TradeProofGenesis",
        "TradeProofSeasonAllocation",
    ]
    reported_names = [item.get("contractName") for item in creates]
    if any(reported_names):
        assert_equal(reported_names, expected_names, "top-level deployment order")

    top_addresses = [item["contractAddress"] for item in creates]
    (
        community_treasury,
        ecosystem_treasury,
        adoption_treasury,
        liquidity_reserve,
        security_reserve,
        contribution,
        genesis,
        season_allocation,
    ) = top_addresses

    receipts = data.get("receipts", [])
    if len(receipts) != EXPECTED_TX_COUNT:
        raise SystemExit(f"Expected {EXPECTED_TX_COUNT} receipts, found {len(receipts)}")
    for receipt in receipts:
        status = receipt.get("status")
        if status not in {1, "1", "0x1"}:
            raise SystemExit(f"Failed deployment receipt: {receipt}")

    transaction_hashes = [item.get("hash") for item in creates]
    if not all(transaction_hashes):
        transaction_hashes = [receipt.get("transactionHash") for receipt in receipts]
    if len(transaction_hashes) != EXPECTED_TX_COUNT or not all(transaction_hashes):
        raise SystemExit("Missing deployment transaction hash")

    blocks = [parse_int(receipt["blockNumber"]) for receipt in receipts]

    token = cast_call(rpc_url, genesis, "token()(address)")
    team_vesting = cast_call(rpc_url, genesis, "teamVesting()(address)")

    contracts = {
        "contribution": contribution,
        "token": token,
        "teamVesting": team_vesting,
        "seasonAllocation": season_allocation,
        "genesis": genesis,
        "communityTreasury": community_treasury,
        "ecosystemTreasury": ecosystem_treasury,
        "adoptionTreasury": adoption_treasury,
        "liquidityReserve": liquidity_reserve,
        "securityReserve": security_reserve,
    }

    code_sizes: dict[str, int] = {}
    for key, address in contracts.items():
        code = command("cast", "code", address, "--rpc-url", rpc_url)
        if code == "0x":
            raise SystemExit(f"No deployed bytecode for {key}: {address}")
        code_sizes[key] = (len(code) - 2) // 2

    assert_equal(
        normalized(cast_call(rpc_url, contribution, "registry()(address)")),
        normalized(EXPECTED_REGISTRY),
        "Contribution Registry",
    )
    assert_equal(
        normalized(cast_call(rpc_url, contribution, "owner()(address)")),
        normalized(operator),
        "Contribution owner",
    )
    assert_equal(
        cast_call(rpc_url, contribution, "reviewers(address)(bool)", operator),
        "true",
        "Contribution reviewer",
    )

    assert_equal(
        int(cast_call(rpc_url, token, "totalSupply()(uint256)")),
        EXPECTED_TOTAL_SUPPLY,
        "Token total supply",
    )
    assert_equal(
        int(cast_call(rpc_url, token, "MAX_SUPPLY()(uint256)")),
        EXPECTED_TOTAL_SUPPLY,
        "Token max supply",
    )

    assert_equal(
        normalized(cast_call(rpc_url, team_vesting, "token()(address)")),
        normalized(token),
        "vesting Token",
    )
    assert_equal(
        normalized(cast_call(rpc_url, team_vesting, "beneficiary()(address)")),
        normalized(operator),
        "vesting beneficiary",
    )
    assert_equal(
        int(cast_call(rpc_url, team_vesting, "released()(uint256)")),
        0,
        "vesting released amount",
    )

    assert_equal(
        normalized(cast_call(rpc_url, season_allocation, "token()(address)")),
        normalized(token),
        "allocation Token",
    )
    assert_equal(
        normalized(cast_call(rpc_url, season_allocation, "contribution()(address)")),
        normalized(contribution),
        "allocation Contribution",
    )
    assert_equal(
        normalized(cast_call(rpc_url, season_allocation, "publisher()(address)")),
        normalized(operator),
        "allocation publisher",
    )
    assert_equal(
        normalized(cast_call(rpc_url, season_allocation, "communityTreasury()(address)")),
        normalized(community_treasury),
        "allocation community treasury",
    )

    vault_keys = (
        "communityTreasury",
        "ecosystemTreasury",
        "adoptionTreasury",
        "liquidityReserve",
        "securityReserve",
    )
    for key, purpose in zip(vault_keys, PURPOSES, strict=True):
        vault = contracts[key]
        assert_equal(
            normalized(cast_call(rpc_url, vault, "operator()(address)")),
            normalized(operator),
            f"{key} operator",
        )
        expected_purpose = command("cast", "keccak", purpose).lower()
        actual_purpose = cast_call(rpc_url, vault, "purposeHash()(bytes32)").lower()
        assert_equal(actual_purpose, expected_purpose, f"{key} purpose")

    for key, expected_balance in BALANCES.items():
        actual_balance = int(
            cast_call(rpc_url, token, "balanceOf(address)(uint256)", contracts[key])
        )
        assert_equal(actual_balance, expected_balance, f"{key} Token balance")

    assert_equal(
        int(cast_call(rpc_url, token, "balanceOf(address)(uint256)", genesis)),
        0,
        "Genesis Token balance",
    )
    assert_equal(
        int(cast_call(rpc_url, token, "balanceOf(address)(uint256)", season_allocation)),
        0,
        "allocation Token balance",
    )
    assert_equal(
        int(cast_call(rpc_url, season_allocation, "totalCommunityCommitted()(uint256)")),
        0,
        "community committed",
    )
    assert_equal(
        int(cast_call(rpc_url, season_allocation, "seasonRevision(uint32)(uint32)", "0")),
        0,
        "Season 0 revision",
    )
    assert_equal(
        int(
            cast_call(
                rpc_url,
                token,
                "allowance(address,address)(uint256)",
                community_treasury,
                season_allocation,
            )
        ),
        0,
        "allocation allowance",
    )

    nonce_after = int(command("cast", "nonce", operator, "--rpc-url", rpc_url))
    balance_after = command("cast", "balance", operator, "--rpc-url", rpc_url)
    assert_equal(nonce_after, EXPECTED_NONCE_AFTER, "operator nonce after")
    assert_equal(nonce_after - nonce_before, EXPECTED_TX_COUNT, "deployment transaction count")

    manifest = {
        "network": "base-sepolia",
        "chainId": 84532,
        "status": "deployed-testnet-inactive",
        "sourceCommit": source_commit,
        "registry": {
            "address": EXPECTED_REGISTRY,
            "existingCanonicalDeployment": True,
        },
        "operator": operator,
        "contracts": contracts,
        "token": {
            "name": "TradeProof Token",
            "symbol": "TPROOF",
            "decimals": 18,
            "maxSupplyTokens": "1000000000",
            "totalSupplyBaseUnits": str(EXPECTED_TOTAL_SUPPLY),
            "publicSaleActive": False,
            "claimActive": False,
            "liquidityPoolActive": False,
        },
        "deployment": {
            "transactionHashes": transaction_hashes,
            "blockFrom": min(blocks),
            "blockTo": max(blocks),
            "deployedAt": datetime.now(timezone.utc).isoformat(),
            "operatorNonceBefore": nonce_before,
            "operatorNonceAfter": nonce_after,
            "operatorBalanceWeiBefore": balance_before,
            "operatorBalanceWeiAfter": balance_after,
            "codeSizes": code_sizes,
            "bytecodeChecks": "pass",
            "sourceVerification": "pending",
        },
        "initialState": {
            "seasonZeroRevision": 0,
            "totalCommunityCommitted": "0",
            "allocationTokenBalance": "0",
            "allocationAllowance": "0",
            "claimActive": False,
            "saleActive": False,
            "liquidityPoolActive": False,
        },
        "boundaries": {
            "testnetOnly": True,
            "publicClaimAuthorized": False,
            "saleAuthorized": False,
            "liquidityAuthorized": False,
            "mainnetAuthorized": False,
            "formalAuditComplete": False,
            "legalLaunchClearance": False,
        },
    }

    output_dir = Path("deployment-output")
    output_dir.mkdir(parents=True, exist_ok=True)
    manifest_path = output_dir / "base-sepolia-economic-stack.json"
    manifest_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")

    comment = f"""<!-- tradeproof-economic-stack-base-sepolia-v0.1 -->
## TradeProof economic stack Base Sepolia deployment: PASS

- Source: `{source_commit}`
- Operator: `{operator}`
- Block range: `{min(blocks)}`–`{max(blocks)}`
- Contribution: `{contribution}`
- TPROOF: `{token}`
- Team vesting: `{team_vesting}`
- Season allocation: `{season_allocation}`
- Genesis: `{genesis}`
- Community treasury: `{community_treasury}`
- Transactions: `{len(transaction_hashes)}`
- Operator nonce: `{nonce_before}` → `{nonce_after}`
- Bytecode checks: **PASS**
- Total supply: `1,000,000,000 TPROOF`
- Season 0 proposal: `none`
- Community committed: `0`
- Claim active: `false`
- Sale active: `false`
- Liquidity pool active: `false`
- Source verification: `pending`

This deployment is testnet-only and does not authorize a claim, sale, market, liquidity action, or mainnet launch.
"""
    (output_dir / "pr-comment.md").write_text(comment, encoding="utf-8")
    print(comment)


if __name__ == "__main__":
    main()
