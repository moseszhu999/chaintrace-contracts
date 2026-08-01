from pathlib import Path

path = Path("README.md")
source = path.read_text(encoding="utf-8")
old = """Only the Registry is deployed. Contribution, Token, vesting, genesis, and seasonal allocation remain source-only until separate deployment gates pass.\n\n## Legacy proof primitives\n"""
new = """Only the Registry is currently deployed. Contribution, Token, vesting, genesis, seasonal allocation, and testnet treasury vaults remain source-only until separate deployment gates pass.\n\n## Base Sepolia economic-stack deployment preparation\n\nThe bounded deployment package adds:\n\n```text\ncontracts/TradeProofTestnetTreasuryVault.sol\nscript/DeployTradeProofEconomicStack.s.sol\ntest/TradeProofEconomicStack.t.sol\ndeployments/base-sepolia-economic-stack.template.json\ndocs/base-sepolia-economic-stack-deployment-v0.1.md\n```\n\nThe script reuses the canonical Registry and deploys Contribution, fixed-supply Token genesis, team vesting, seasonal allocation, and five visibly centralized Base Sepolia treasury vaults. The five vaults and the testnet operator are not a production governance design.\n\nA successful testnet deployment must begin with no season proposal, no allocation funding, no active claim, no Token sale, no liquidity pool, and no market. The deployment branch prepares source and tests only; transaction broadcast and canonical evidence remain a separate operational step.\n\n## Legacy proof primitives\n"""
if new not in source:
    if old not in source:
        raise SystemExit("README deployment-status marker not found")
    source = source.replace(old, new, 1)
path.write_text(source, encoding="utf-8")
