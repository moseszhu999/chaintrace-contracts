// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { TradeProofRegistry } from "../contracts/TradeProofRegistry.sol";
import { TradeProofContribution } from "../contracts/TradeProofContribution.sol";
import { TradeProofGenesis } from "../contracts/TradeProofGenesis.sol";
import { TradeProofToken } from "../contracts/TradeProofToken.sol";
import { TradeProofTeamVesting } from "../contracts/TradeProofTeamVesting.sol";
import { TradeProofSeasonAllocation } from "../contracts/TradeProofSeasonAllocation.sol";
import { TradeProofTestnetTreasuryVault } from "../contracts/TradeProofTestnetTreasuryVault.sol";

interface VmEconomicStackTest {
    function prank(address caller) external;
    function expectRevert(bytes calldata revertData) external;
    function expectRevert(bytes4 selector) external;
}

contract TradeProofEconomicStackTest {
    VmEconomicStackTest private constant vm =
        VmEconomicStackTest(address(uint160(uint256(keccak256("hevm cheat code")))));

    address private constant OPERATOR = address(0x0F3A);
    address private constant TEAM = address(0x7EAA);
    address private constant ALICE = address(0xA11CE);

    bytes32 private constant COMMUNITY_PURPOSE = keccak256("TPROOF_TESTNET_COMMUNITY");
    bytes32 private constant ECOSYSTEM_PURPOSE = keccak256("TPROOF_TESTNET_ECOSYSTEM");
    bytes32 private constant ADOPTION_PURPOSE = keccak256("TPROOF_TESTNET_ADOPTION");
    bytes32 private constant LIQUIDITY_PURPOSE =
        keccak256("TPROOF_TESTNET_LIQUIDITY_RESERVE");
    bytes32 private constant SECURITY_PURPOSE =
        keccak256("TPROOF_TESTNET_SECURITY_RESERVE");

    TradeProofRegistry private registry;
    TradeProofContribution private contribution;
    TradeProofGenesis private genesis;
    TradeProofToken private token;
    TradeProofTeamVesting private teamVesting;
    TradeProofSeasonAllocation private seasonAllocation;
    TradeProofTestnetTreasuryVault private communityTreasury;
    TradeProofTestnetTreasuryVault private ecosystemTreasury;
    TradeProofTestnetTreasuryVault private adoptionTreasury;
    TradeProofTestnetTreasuryVault private liquidityReserve;
    TradeProofTestnetTreasuryVault private securityReserve;

    function setUp() public {
        registry = new TradeProofRegistry();
        communityTreasury = new TradeProofTestnetTreasuryVault(OPERATOR, COMMUNITY_PURPOSE);
        ecosystemTreasury = new TradeProofTestnetTreasuryVault(OPERATOR, ECOSYSTEM_PURPOSE);
        adoptionTreasury = new TradeProofTestnetTreasuryVault(OPERATOR, ADOPTION_PURPOSE);
        liquidityReserve = new TradeProofTestnetTreasuryVault(OPERATOR, LIQUIDITY_PURPOSE);
        securityReserve = new TradeProofTestnetTreasuryVault(OPERATOR, SECURITY_PURPOSE);
        contribution = new TradeProofContribution(registry);
        genesis = new TradeProofGenesis(
            address(communityTreasury),
            address(ecosystemTreasury),
            TEAM,
            address(adoptionTreasury),
            address(liquidityReserve),
            address(securityReserve),
            uint64(block.timestamp)
        );
        token = genesis.token();
        teamVesting = genesis.teamVesting();
        seasonAllocation =
            new TradeProofSeasonAllocation(token, contribution, OPERATOR, address(communityTreasury));
    }

    function testEconomicStackUsesExistingRegistryAndIndependentContributionState() public view {
        _assertEq(address(contribution.registry()), address(registry), "registry reference");
        _assertEq(contribution.owner(), address(this), "contribution deployer owner");
        _assertTrue(contribution.reviewers(address(this)), "initial reviewer");
        _assertEq(contribution.currentSeason(), 0, "initial season");
    }

    function testFiveTreasuriesAreDistinctAndPurposeBound() public view {
        address[5] memory vaults = [
            address(communityTreasury),
            address(ecosystemTreasury),
            address(adoptionTreasury),
            address(liquidityReserve),
            address(securityReserve)
        ];
        for (uint256 index = 0; index < vaults.length; index++) {
            _assertTrue(vaults[index] != address(0), "nonzero vault");
            for (uint256 prior = 0; prior < index; prior++) {
                _assertTrue(vaults[index] != vaults[prior], "distinct vault");
            }
        }
        _assertEq(communityTreasury.operator(), OPERATOR, "community operator");
        _assertEq(communityTreasury.purposeHash(), COMMUNITY_PURPOSE, "community purpose");
        _assertEq(ecosystemTreasury.purposeHash(), ECOSYSTEM_PURPOSE, "ecosystem purpose");
        _assertEq(adoptionTreasury.purposeHash(), ADOPTION_PURPOSE, "adoption purpose");
        _assertEq(liquidityReserve.purposeHash(), LIQUIDITY_PURPOSE, "liquidity purpose");
        _assertEq(securityReserve.purposeHash(), SECURITY_PURPOSE, "security purpose");
    }

    function testGenesisAllocationsLandInExactVaultsAndVesting() public view {
        _assertEq(token.totalSupply(), token.MAX_SUPPLY(), "fixed supply");
        _assertEq(
            token.balanceOf(address(communityTreasury)),
            token.COMMUNITY_ALLOCATION(),
            "community balance"
        );
        _assertEq(
            token.balanceOf(address(ecosystemTreasury)),
            token.ECOSYSTEM_ALLOCATION(),
            "ecosystem balance"
        );
        _assertEq(
            token.balanceOf(address(adoptionTreasury)),
            token.ADOPTION_ALLOCATION(),
            "adoption balance"
        );
        _assertEq(
            token.balanceOf(address(liquidityReserve)),
            token.LIQUIDITY_RESERVE_ALLOCATION(),
            "liquidity balance"
        );
        _assertEq(
            token.balanceOf(address(securityReserve)),
            token.SECURITY_RESERVE_ALLOCATION(),
            "security balance"
        );
        _assertEq(
            token.balanceOf(address(teamVesting)), token.TEAM_ALLOCATION(), "team vesting balance"
        );
        _assertEq(token.balanceOf(address(genesis)), 0, "genesis zero balance");
        _assertEq(teamVesting.beneficiary(), TEAM, "team beneficiary");
    }

    function testSeasonAllocationIsUnfundedAndInactiveAtDeployment() public view {
        TradeProofSeasonAllocation.Distribution memory distribution =
            seasonAllocation.getDistribution(0);
        _assertEq(
            uint256(distribution.state),
            uint256(TradeProofSeasonAllocation.DistributionState.None),
            "no season proposal"
        );
        _assertEq(token.balanceOf(address(seasonAllocation)), 0, "allocation zero balance");
        _assertEq(
            token.allowance(address(communityTreasury), address(seasonAllocation)),
            0,
            "no treasury allowance"
        );
        _assertEq(seasonAllocation.totalCommunityCommitted(), 0, "no community commitment");
    }

    function testCommunityVaultCanApproveReviewedAllocationContract() public {
        uint256 amount = seasonAllocation.GENESIS_PROOF_POOL();
        vm.prank(OPERATOR);
        communityTreasury.approveToken(address(token), address(seasonAllocation), amount);
        _assertEq(
            token.allowance(address(communityTreasury), address(seasonAllocation)),
            amount,
            "exact allowance"
        );
        _assertEq(token.balanceOf(address(seasonAllocation)), 0, "approval moves no tokens");
    }

    function testVaultCanTransferTokenOnlyWhenOperatorExplicitlyActs() public {
        uint256 amount = 1_000 * 1e18;
        vm.prank(OPERATOR);
        ecosystemTreasury.transferToken(address(token), ALICE, amount);
        _assertEq(token.balanceOf(ALICE), amount, "recipient balance");
        _assertEq(
            token.balanceOf(address(ecosystemTreasury)),
            token.ECOSYSTEM_ALLOCATION() - amount,
            "vault balance"
        );
    }

    function testNonOperatorCannotApproveOrTransferVaultTokens() public {
        vm.expectRevert(
            abi.encodeWithSelector(TradeProofTestnetTreasuryVault.NotOperator.selector, ALICE)
        );
        vm.prank(ALICE);
        communityTreasury.approveToken(address(token), address(seasonAllocation), 1);

        vm.expectRevert(
            abi.encodeWithSelector(TradeProofTestnetTreasuryVault.NotOperator.selector, ALICE)
        );
        vm.prank(ALICE);
        communityTreasury.transferToken(address(token), ALICE, 1);
    }

    function testVaultRejectsZeroOperatorPurposeAndTokenTargets() public {
        vm.expectRevert(TradeProofTestnetTreasuryVault.ZeroAddress.selector);
        new TradeProofTestnetTreasuryVault(address(0), COMMUNITY_PURPOSE);

        vm.expectRevert(TradeProofTestnetTreasuryVault.ZeroPurposeHash.selector);
        new TradeProofTestnetTreasuryVault(OPERATOR, bytes32(0));

        vm.expectRevert(TradeProofTestnetTreasuryVault.ZeroAddress.selector);
        vm.prank(OPERATOR);
        communityTreasury.approveToken(address(0), address(seasonAllocation), 1);

        vm.expectRevert(TradeProofTestnetTreasuryVault.ZeroAddress.selector);
        vm.prank(OPERATOR);
        communityTreasury.transferToken(address(token), address(0), 1);
    }

    function testTestnetVaultHasNoOwnershipTransferOrUpgradeSurface() public {
        (bool ownerTransferSuccess,) = address(communityTreasury).call(
            abi.encodeWithSignature("transferOwnership(address)", ALICE)
        );
        (bool upgradeSuccess,) =
            address(communityTreasury).call(abi.encodeWithSignature("upgradeTo(address)", ALICE));
        (bool ethSweepSuccess,) =
            address(communityTreasury).call(abi.encodeWithSignature("sweepEth(address)", ALICE));
        _assertFalse(ownerTransferSuccess, "ownership transfer surface");
        _assertFalse(upgradeSuccess, "upgrade surface");
        _assertFalse(ethSweepSuccess, "ETH sweep surface");
    }

    function _assertTrue(bool value, string memory message) private pure {
        require(value, message);
    }

    function _assertFalse(bool value, string memory message) private pure {
        require(!value, message);
    }

    function _assertEq(address left, address right, string memory message) private pure {
        require(left == right, message);
    }

    function _assertEq(bytes32 left, bytes32 right, string memory message) private pure {
        require(left == right, message);
    }

    function _assertEq(uint256 left, uint256 right, string memory message) private pure {
        require(left == right, message);
    }
}
