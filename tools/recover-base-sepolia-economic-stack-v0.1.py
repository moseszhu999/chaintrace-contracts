#!/usr/bin/env python3
"""Recover and verify Base Sepolia TradeProof economic-stack deployment evidence.

This script is strictly read-only. It does not read a private key, sign a payload,
or send a transaction. It reconstructs the eight top-level deployment transactions
from Blockscout, verifies their receipts through Base Sepolia RPC, and checks the
on-chain economic-stack invariants before writing canonical evidence.
"""

from __future__ import annotations

import json
import os
import subprocess
import time
import urllib.request
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

NETWORK = "base-sepolia"
CHAIN_ID = 84532
SOURCE_COMMIT = "005839c62c1a67392b2f5cced25374f5b48fecc1"
REGISTRY = "0xad1c714140ceb8ed7c5234d939a06926f5edaba2"
OPERATOR = "0x072A01FE3DdbF351DAaf6Da70CE5E67f5101fEC9"
EXPECTED_NONCE_AFTER = 10
EXPECTED_TOTAL_SUPPLY = 1_000_000_000 * 10**18
BLOCKSCOUT_URL = (
    "https://base-sepolia.blockscout.com/api/v2/addresses/"
    f"{OPERATOR}/transactions"
)

TOP_LEVEL_BY_NONCE = {
    2: ("communityTreasury", "0xBf485863EA313b75dC6cf389A9A86Bd98a0dF910"),
    3: ("ecosystemTreasury", "0x3Ca8dd7dF625d51aF1Da77716269D788DD869089"),
    4: ("adoptionTreasury", "0x895C0C8749EF5DE94BA544cf28dDEd68fd6b3Aba"),
    5: ("liquidityReserve", "0xC7F135d85aAe58bd409F7263FadbD041d6031B92"),
    6: ("securityReserve", "0x594ce0619d5bAcA2F66992c89610cb57A704d0AB"),
    7: ("contribution", "0xcb33eA69dDa48f2A345Fc1F2A3B85f329a5eb1E0"),
    8: ("genesis", "0x2a00707664d738d41EDc4e453F173D38f6D83ECb"),
    9: ("seasonAllocation", "0x0bFd6CEab5dB51d7B53789484ECD147B10D7fC65"),
}

TOKEN = "0xd0a60427482C2cBE1C6566772DC5838AA06DED80"
TEAM_VESTING = "0x65Ab9CE997975f18b6a06957D75AA5a00b3dc467"

PURPOSES = {
    "communityTreasury": "TPROOF_TESTNET_COMMUNITY",
    "ecosystemTreasury": "TPROOF_TESTNET_ECOSYSTEM",
    "adoptionTreasury": "TPROOF_TESTNET_ADOPTION",
    "liquidityReserve": "TPROOF_TESTNET_LIQUIDITY_RESERVE",
    "securityReserve": "TPROOF_TESTNET_SECURITY_RESERVE",
}

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


def normalize(address: str) -> str:
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


def cast_call(rpc_url: str, address: str, signature: str, *args: str) -> str:
    return first_token(command("cast", "call", address, signature, *args, "--rpc-url", rpc_url))


def fetch_json(url: str, attempts: int = 10, delay_seconds: int = 6) -> dict[str, Any]:
    last_error: Exception | None = None
    for attempt in range(attempts):
        try:
            request = urllib.request.Request(
                url,
                headers={"User-Agent": "TradeProof-Evidence-Recovery/0.1"},
            )
            with urllib.request.urlopen(request, timeout=30) as response:
                return json.loads(response.read().decode("utf-8"))
        except Exception as exc:  # noqa: BLE001 - bounded network retry
            last_error = exc
            if attempt + 1 < attempts:
                time.sleep(delay_seconds)
    raise SystemExit(f"Unable to fetch {url}: {last_error}")


def code_with_retry(rpc_url: str, address: str) -> str:
    for attempt in range(12):
        code = command("cast", "code", address, "--rpc-url", rpc_url)
        if code != "0x":
            return code
        if attempt < 11:
            time.sleep(5)
    raise SystemExit(f"No deployed bytecode after propagation wait: {address}")


def receipt(rpc_url: str, transaction_hash: str) -> dict[str, Any]:
    output = command("cast", "receipt", transaction_hash, "--rpc-url", rpc_url, "--json")
    return json.loads(output)


def blockscout_from(item: dict[str, Any]) -> str:
    sender = item.get("from")
    if isinstance(sender, dict):
        return str(sender.get("hash", ""))
    return str(sender or "")


def blockscout_nonce(item: dict[str, Any]) -> int:
    return parse_int(item.get("nonce", -1))


def blockscout_hash(item: dict[str, Any]) -> str:
    return str(item.get("hash", ""))


def main() -> None:
    rpc_url = require_env("BASE_SEPOLIA_RPC_URL")

    chain_id = int(command("cast", "chain-id", "--rpc-url", rpc_url))
    assert_equal(chain_id, CHAIN_ID, "chain ID")

    nonce_after = int(command("cast", "nonce", OPERATOR, "--rpc-url", rpc_url))
    assert_equal(nonce_after, EXPECTED_NONCE_AFTER, "operator nonce after deployment")

    registry_code = code_with_retry(rpc_url, REGISTRY)
    if registry_code == "0x":
        raise SystemExit("Canonical Registry bytecode missing")

    blockscout = fetch_json(BLOCKSCOUT_URL)
    raw_items = blockscout.get("items", [])
    deployment_items: dict[int, dict[str, Any]] = {}
    for item in raw_items:
        if normalize(blockscout_from(item)) != normalize(OPERATOR):
            continue
        nonce = blockscout_nonce(item)
        if nonce in TOP_LEVEL_BY_NONCE:
            deployment_items[nonce] = item

    assert_equal(sorted(deployment_items), list(range(2, 10)), "deployment transaction nonces")

    transactions: list[dict[str, Any]] = []
    blocks: list[int] = []
    timestamps: list[str] = []
    for nonce in range(2, 10):
        label, expected_contract = TOP_LEVEL_BY_NONCE[nonce]
        item = deployment_items[nonce]
        transaction_hash = blockscout_hash(item)
        if not transaction_hash.startswith("0x") or len(transaction_hash) != 66:
            raise SystemExit(f"Invalid transaction hash for nonce {nonce}: {transaction_hash}")
        if str(item.get("status", "")).lower() not in {"ok", "success"}:
            raise SystemExit(f"Blockscout reports failed transaction at nonce {nonce}")

        tx_receipt = receipt(rpc_url, transaction_hash)
        status = parse_int(tx_receipt.get("status", 0))
        assert_equal(status, 1, f"receipt status nonce {nonce}")
        created_contract = str(tx_receipt.get("contractAddress") or "")
        assert_equal(normalize(created_contract), normalize(expected_contract), f"created contract nonce {nonce}")
        block_number = parse_int(tx_receipt["blockNumber"])
        blocks.append(block_number)
        timestamp = str(item.get("timestamp", ""))
        if timestamp:
            timestamps.append(timestamp)
        transactions.append(
            {
                "nonce": nonce,
                "hash": transaction_hash,
                "blockNumber": block_number,
                "contract": label,
                "contractAddress": expected_contract,
                "status": "success",
            }
        )

    contracts = {label: address for label, address in TOP_LEVEL_BY_NONCE.values()}
    contracts["token"] = TOKEN
    contracts["teamVesting"] = TEAM_VESTING

    code_sizes: dict[str, int] = {}
    for label, address in contracts.items():
        code = code_with_retry(rpc_url, address)
        code_sizes[label] = (len(code) - 2) // 2

    assert_equal(
        normalize(cast_call(rpc_url, contracts["contribution"], "registry()(address)")),
        normalize(REGISTRY),
        "Contribution Registry",
    )
    assert_equal(
        normalize(cast_call(rpc_url, contracts["contribution"], "owner()(address)")),
        normalize(OPERATOR),
        "Contribution owner",
    )
    assert_equal(
        cast_call(rpc_url, contracts["contribution"], "reviewers(address)(bool)", OPERATOR),
        "true",
        "Contribution reviewer",
    )

    assert_equal(
        normalize(cast_call(rpc_url, contracts["genesis"], "token()(address)")),
        normalize(TOKEN),
        "Genesis Token",
    )
    assert_equal(
        normalize(cast_call(rpc_url, contracts["genesis"], "teamVesting()(address)")),
        normalize(TEAM_VESTING),
        "Genesis team vesting",
    )

    assert_equal(
        int(cast_call(rpc_url, TOKEN, "totalSupply()(uint256)")),
        EXPECTED_TOTAL_SUPPLY,
        "Token total supply",
    )
    assert_equal(
        int(cast_call(rpc_url, TOKEN, "MAX_SUPPLY()(uint256)")),
        EXPECTED_TOTAL_SUPPLY,
        "Token max supply",
    )

    assert_equal(
        normalize(cast_call(rpc_url, TEAM_VESTING, "token()(address)")),
        normalize(TOKEN),
        "vesting Token",
    )
    assert_equal(
        normalize(cast_call(rpc_url, TEAM_VESTING, "beneficiary()(address)")),
        normalize(OPERATOR),
        "vesting beneficiary",
    )
    assert_equal(
        int(cast_call(rpc_url, TEAM_VESTING, "released()(uint256)")),
        0,
        "vesting released",
    )

    allocation = contracts["seasonAllocation"]
    assert_equal(
        normalize(cast_call(rpc_url, allocation, "token()(address)")),
        normalize(TOKEN),
        "allocation Token",
    )
    assert_equal(
        normalize(cast_call(rpc_url, allocation, "contribution()(address)")),
        normalize(contracts["contribution"]),
        "allocation Contribution",
    )
    assert_equal(
        normalize(cast_call(rpc_url, allocation, "publisher()(address)")),
        normalize(OPERATOR),
        "allocation publisher",
    )
    assert_equal(
        normalize(cast_call(rpc_url, allocation, "communityTreasury()(address)")),
        normalize(contracts["communityTreasury"]),
        "allocation community treasury",
    )

    for label, purpose in PURPOSES.items():
        vault = contracts[label]
        assert_equal(
            normalize(cast_call(rpc_url, vault, "operator()(address)")),
            normalize(OPERATOR),
            f"{label} operator",
        )
        expected_purpose = command("cast", "keccak", purpose).lower()
        actual_purpose = cast_call(rpc_url, vault, "purposeHash()(bytes32)").lower()
        assert_equal(actual_purpose, expected_purpose, f"{label} purpose")

    balance_addresses = dict(contracts)
    balance_addresses["teamVesting"] = TEAM_VESTING
    for label, expected_balance in BALANCES.items():
        actual = int(cast_call(rpc_url, TOKEN, "balanceOf(address)(uint256)", balance_addresses[label]))
        assert_equal(actual, expected_balance, f"{label} Token balance")

    assert_equal(
        int(cast_call(rpc_url, TOKEN, "balanceOf(address)(uint256)", contracts["genesis"])),
        0,
        "Genesis Token balance",
    )
    assert_equal(
        int(cast_call(rpc_url, TOKEN, "balanceOf(address)(uint256)", allocation)),
        0,
        "allocation Token balance",
    )
    assert_equal(
        int(cast_call(rpc_url, allocation, "totalCommunityCommitted()(uint256)")),
        0,
        "community committed",
    )
    assert_equal(
        int(cast_call(rpc_url, allocation, "seasonRevision(uint32)(uint32)", "0")),
        0,
        "Season 0 revision",
    )
    assert_equal(
        int(
            cast_call(
                rpc_url,
                TOKEN,
                "allowance(address,address)(uint256)",
                contracts["communityTreasury"],
                allocation,
            )
        ),
        0,
        "allocation allowance",
    )

    manifest = {
        "network": NETWORK,
        "chainId": CHAIN_ID,
        "status": "deployed-testnet-inactive",
        "sourceCommit": SOURCE_COMMIT,
        "registry": {
            "address": REGISTRY,
            "existingCanonicalDeployment": True,
        },
        "operator": OPERATOR,
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
            "transactions": transactions,
            "blockFrom": min(blocks),
            "blockTo": max(blocks),
            "timestampFrom": min(timestamps) if timestamps else None,
            "timestampTo": max(timestamps) if timestamps else None,
            "operatorNonceBefore": 2,
            "operatorNonceAfter": nonce_after,
            "codeSizes": code_sizes,
            "bytecodeChecks": "pass",
            "evidenceRecoveredAfterRpcPropagationLag": True,
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
        "evidenceGeneratedAt": datetime.now(timezone.utc).isoformat(),
    }

    output_dir = Path("deployment-output")
    output_dir.mkdir(parents=True, exist_ok=True)
    (output_dir / "base-sepolia-economic-stack.json").write_text(
        json.dumps(manifest, indent=2) + "\n", encoding="utf-8"
    )
    (output_dir / "blockscout-operator-transactions.json").write_text(
        json.dumps(blockscout, indent=2) + "\n", encoding="utf-8"
    )

    comment = f"""<!-- tradeproof-economic-stack-base-sepolia-v0.1 -->
## TradeProof economic stack Base Sepolia deployment: PASS

- Source: `{SOURCE_COMMIT}`
- Operator: `{OPERATOR}`
- Block range: `{min(blocks)}`–`{max(blocks)}`
- Contribution: `{contracts['contribution']}`
- TPROOF: `{TOKEN}`
- Team vesting: `{TEAM_VESTING}`
- Season allocation: `{allocation}`
- Genesis: `{contracts['genesis']}`
- Community treasury: `{contracts['communityTreasury']}`
- Transactions: `8` (`nonce 2 → 10`)
- Bytecode checks: **PASS**
- Total supply: `1,000,000,000 TPROOF`
- Season 0 proposal: `none`
- Community committed: `0`
- Claim active: `false`
- Sale active: `false`
- Liquidity pool active: `false`
- Evidence recovery: read-only after RPC propagation lag
- Source verification: `pending`

This deployment is testnet-only and does not authorize a claim, sale, market, liquidity action, or mainnet launch.
"""
    (output_dir / "pr-comment.md").write_text(comment, encoding="utf-8")
    print(comment)


if __name__ == "__main__":
    main()
