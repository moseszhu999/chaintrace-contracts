// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { TradeProofRegistry } from "../contracts/TradeProofRegistry.sol";
import { TradeProofContribution } from "../contracts/TradeProofContribution.sol";
import { TradeProofGenesis } from "../contracts/TradeProofGenesis.sol";
import { TradeProofToken } from "../contracts/TradeProofToken.sol";
import { TradeProofTeamVesting } from "../contracts/TradeProofTeamVesting.sol";
import { TradeProofSeasonAllocation } from "../contracts/TradeProofSeasonAllocation.sol";
import { TradeProofTestnetTreasuryVault } from "../contracts/TradeProofTestnetTreasuryVault.sol";

interface VmEconomicStack {
    function envAddress(string calldata name) external returns (address value);
    function startBroadcast() external;
    function stopBroadcast() external;
}

/// @notice Deploys the source-reviewed TradeProof economic stack for Base Sepolia demonstration.
/// @dev No season is proposed, funded, activated, or claimable by this script.
contract DeployTradeProofEconomicStack {
    VmEconomicStack private constant vm =
        VmEconomicStack(address(uint160(uint256(keccak256("hevm cheat code")))));

    bytes32 public constant COMMUNITY_PURPOSE = keccak256("TPROOF_TESTNET_COMMUNITY");
    bytes32 public constant ECOSYSTEM_PURPOSE = keccak256("TPROOF_TESTNET_ECOSYSTEM");
    bytes32 public constant ADOPTION_PURPOSE = keccak256("TPROOF_TESTNET_ADOPTION");
    bytes32 public constant LIQUIDITY_PURPOSE = keccak256("TPROOF_TESTNET_LIQUIDITY_RESERVE");
    bytes32 public constant SECURITY_PURPOSE = keccak256("TPROOF_TESTNET_SECURITY_RESERVE");

    error ZeroAddress();
    error InvalidRegistry(address registry);
    error AllocationInvariantFailed();

    event EconomicStackDeployed(
        address indexed operator,
        address indexed registry,
        address indexed contribution,
        address token,
        address teamVesting,
        address seasonAllocation,
        address genesis,
        address communityTreasury,
        address ecosystemTreasury,
        address adoptionTreasury,
        address liquidityReserve,
        address securityReserve,
        uint64 teamVestingStart
    );

    struct Deployment {
        TradeProofRegistry registry;
        TradeProofContribution contribution;
        TradeProofToken token;
        TradeProofTeamVesting teamVesting;
        TradeProofSeasonAllocation seasonAllocation;
        TradeProofGenesis genesis;
        TradeProofTestnetTreasuryVault communityTreasury;
        TradeProofTestnetTreasuryVault ecosystemTreasury;
        TradeProofTestnetTreasuryVault adoptionTreasury;
        TradeProofTestnetTreasuryVault liquidityReserve;
        TradeProofTestnetTreasuryVault securityReserve;
        address operator;
        uint64 teamVestingStart;
    }

    function run() external returns (Deployment memory deployment) {
        address registryAddress = vm.envAddress("TRADE_PROOF_REGISTRY");
        address operator = vm.envAddress("TESTNET_OPERATOR");
        if (registryAddress == address(0) || operator == address(0)) revert ZeroAddress();
        if (registryAddress.code.length == 0) revert InvalidRegistry(registryAddress);

        deployment.registry = TradeProofRegistry(registryAddress);
        deployment.operator = operator;
        deployment.teamVestingStart = uint64(block.timestamp);

        vm.startBroadcast();
        deployment.communityTreasury =
            new TradeProofTestnetTreasuryVault(operator, COMMUNITY_PURPOSE);
        deployment.ecosystemTreasury =
            new TradeProofTestnetTreasuryVault(operator, ECOSYSTEM_PURPOSE);
        deployment.adoptionTreasury =
            new TradeProofTestnetTreasuryVault(operator, ADOPTION_PURPOSE);
        deployment.liquidityReserve =
            new TradeProofTestnetTreasuryVault(operator, LIQUIDITY_PURPOSE);
        deployment.securityReserve =
            new TradeProofTestnetTreasuryVault(operator, SECURITY_PURPOSE);

        deployment.contribution = new TradeProofContribution(deployment.registry);
        deployment.genesis = new TradeProofGenesis(
            address(deployment.communityTreasury),
            address(deployment.ecosystemTreasury),
            operator,
            address(deployment.adoptionTreasury),
            address(deployment.liquidityReserve),
            address(deployment.securityReserve),
            deployment.teamVestingStart
        );
        deployment.token = deployment.genesis.token();
        deployment.teamVesting = deployment.genesis.teamVesting();
        deployment.seasonAllocation = new TradeProofSeasonAllocation(
            deployment.token,
            deployment.contribution,
            operator,
            address(deployment.communityTreasury)
        );
        vm.stopBroadcast();

        if (
            deployment.token.totalSupply() != deployment.token.MAX_SUPPLY()
                || deployment.token.balanceOf(address(deployment.communityTreasury))
                    != deployment.token.COMMUNITY_ALLOCATION()
                || deployment.token.balanceOf(address(deployment.ecosystemTreasury))
                    != deployment.token.ECOSYSTEM_ALLOCATION()
                || deployment.token.balanceOf(address(deployment.teamVesting))
                    != deployment.token.TEAM_ALLOCATION()
                || deployment.token.balanceOf(address(deployment.adoptionTreasury))
                    != deployment.token.ADOPTION_ALLOCATION()
                || deployment.token.balanceOf(address(deployment.liquidityReserve))
                    != deployment.token.LIQUIDITY_RESERVE_ALLOCATION()
                || deployment.token.balanceOf(address(deployment.securityReserve))
                    != deployment.token.SECURITY_RESERVE_ALLOCATION()
                || deployment.token.balanceOf(address(deployment.genesis)) != 0
        ) {
            revert AllocationInvariantFailed();
        }

        emit EconomicStackDeployed(
            operator,
            registryAddress,
            address(deployment.contribution),
            address(deployment.token),
            address(deployment.teamVesting),
            address(deployment.seasonAllocation),
            address(deployment.genesis),
            address(deployment.communityTreasury),
            address(deployment.ecosystemTreasury),
            address(deployment.adoptionTreasury),
            address(deployment.liquidityReserve),
            address(deployment.securityReserve),
            deployment.teamVestingStart
        );
    }
}
