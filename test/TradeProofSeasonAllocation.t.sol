// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { TradeProofRegistry } from "../contracts/TradeProofRegistry.sol";
import { TradeProofContribution } from "../contracts/TradeProofContribution.sol";
import { TradeProofToken } from "../contracts/TradeProofToken.sol";
import { TradeProofGenesis } from "../contracts/TradeProofGenesis.sol";
import { TradeProofSeasonAllocation } from "../contracts/TradeProofSeasonAllocation.sol";

interface VmSeasonAllocation {
    function prank(address caller) external;
    function expectRevert(bytes calldata revertData) external;
    function expectRevert(bytes4 selector) external;
    function warp(uint256 timestamp) external;
}

contract TradeProofSeasonAllocationTest {
    VmSeasonAllocation private constant vm =
        VmSeasonAllocation(address(uint160(uint256(keccak256("hevm cheat code")))));

    address private constant COMMUNITY = address(0xC011);
    address private constant ECOSYSTEM = address(0xEC05);
    address private constant TEAM = address(0x7EAA);
    address private constant ADOPTION = address(0xAD07);
    address private constant LIQUIDITY = address(0x110D);
    address private constant SECURITY = address(0x5EC);
    address private constant PUBLISHER = address(0xB11C);
    address private constant ALICE = address(0xA11CE);
    address private constant BOB = address(0xB0B);
    address private constant CAROL = address(0xCA401);
    address private constant RELAYER = address(0xAE1A);

    uint256 private constant ALICE_POINTS = 100;
    uint256 private constant BOB_POINTS = 225;
    uint256 private constant ALICE_AMOUNT = 4_000_000 * 1e18;
    uint256 private constant BOB_AMOUNT = 6_000_000 * 1e18;
    bytes32 private constant DATASET_DIGEST = bytes32(uint256(0xDA7A));
    bytes32 private constant CANCEL_REASON = bytes32(uint256(0xCA11));

    TradeProofRegistry private registry;
    TradeProofContribution private contribution;
    TradeProofGenesis private genesis;
    TradeProofToken private token;
    TradeProofSeasonAllocation private allocation;

    function setUp() public {
        registry = new TradeProofRegistry();
        contribution = new TradeProofContribution(registry);
        genesis = new TradeProofGenesis(
            COMMUNITY,
            ECOSYSTEM,
            TEAM,
            ADOPTION,
            LIQUIDITY,
            SECURITY,
            uint64(block.timestamp)
        );
        token = genesis.token();
        allocation =
            new TradeProofSeasonAllocation(token, contribution, PUBLISHER, COMMUNITY);
        vm.prank(COMMUNITY);
        token.approve(address(allocation), type(uint256).max);
    }

    function testClosedSeasonCanBeProposedFundedAndActivated() public {
        _closeSeasonZeroWithPoints();
        (bytes32 root,,) = _genesisRoot(1);
        _proposeGenesis(root);

        vm.prank(PUBLISHER);
        uint256 funded = allocation.fundSeason(0);
        _assertEq(funded, 10_000_000 * 1e18, "funded amount");
        _assertEq(token.balanceOf(address(allocation)), funded, "allocation balance");
        _assertEq(allocation.totalCommunityCommitted(), funded, "community committed");

        TradeProofSeasonAllocation.Distribution memory distribution =
            allocation.getDistribution(0);
        vm.warp(distribution.claimableAt);
        allocation.activateSeason(0);
        distribution = allocation.getDistribution(0);
        _assertEq(
            uint256(distribution.state),
            uint256(TradeProofSeasonAllocation.DistributionState.Active),
            "active state"
        );
    }

    function testSeasonProposalRequiresClosedContributionSeason() public {
        (bytes32 root,,) = _genesisRoot(1);
        vm.expectRevert(
            abi.encodeWithSelector(TradeProofSeasonAllocation.SeasonNotClosed.selector, 0)
        );
        vm.prank(PUBLISHER);
        allocation.proposeSeason(0, root, DATASET_DIGEST, 2, 10_000_000 * 1e18);
    }

    function testOnlyImmutablePublisherMayProposeOrFund() public {
        _closeSeasonZeroWithPoints();
        (bytes32 root,,) = _genesisRoot(1);
        vm.expectRevert(
            abi.encodeWithSelector(TradeProofSeasonAllocation.NotPublisher.selector, ALICE)
        );
        vm.prank(ALICE);
        allocation.proposeSeason(0, root, DATASET_DIGEST, 2, 10_000_000 * 1e18);

        _proposeGenesis(root);
        vm.expectRevert(
            abi.encodeWithSelector(TradeProofSeasonAllocation.NotPublisher.selector, ALICE)
        );
        vm.prank(ALICE);
        allocation.fundSeason(0);
    }

    function testGenesisPoolMustEqualTenMillionTokens() public {
        _closeSeasonZeroWithPoints();
        (bytes32 root,,) = _genesisRoot(1);
        uint256 wrongAmount = 9_999_999 * 1e18;
        vm.expectRevert(
            abi.encodeWithSelector(
                TradeProofSeasonAllocation.GenesisPoolMismatch.selector,
                wrongAmount,
                10_000_000 * 1e18
            )
        );
        vm.prank(PUBLISHER);
        allocation.proposeSeason(0, root, DATASET_DIGEST, 2, wrongAmount);
    }

    function testActivationRequiresSevenDayDelayAndFullFunding() public {
        _closeSeasonZeroWithPoints();
        (bytes32 root,,) = _genesisRoot(1);
        _proposeGenesis(root);
        TradeProofSeasonAllocation.Distribution memory distribution =
            allocation.getDistribution(0);

        vm.expectRevert(
            abi.encodeWithSelector(
                TradeProofSeasonAllocation.ClaimDelayActive.selector,
                0,
                distribution.claimableAt
            )
        );
        allocation.activateSeason(0);

        vm.warp(distribution.claimableAt);
        vm.expectRevert(
            abi.encodeWithSelector(
                TradeProofSeasonAllocation.DistributionNotFullyFunded.selector,
                0,
                0,
                10_000_000 * 1e18
            )
        );
        allocation.activateSeason(0);
    }

    function testTwoValidClaimsCompleteGenesisDistribution() public {
        _closeSeasonZeroWithPoints();
        (bytes32 root, bytes32 aliceLeaf, bytes32 bobLeaf) = _genesisRoot(1);
        _proposeFundAndActivateGenesis(root);

        bytes32[] memory aliceProof = new bytes32[](1);
        aliceProof[0] = bobLeaf;
        allocation.claim(0, ALICE, ALICE_POINTS, ALICE_AMOUNT, aliceProof);
        _assertEq(token.balanceOf(ALICE), ALICE_AMOUNT, "alice allocation");
        _assertTrue(allocation.hasClaimed(0, ALICE), "alice claimed");

        bytes32[] memory bobProof = new bytes32[](1);
        bobProof[0] = aliceLeaf;
        allocation.claim(0, BOB, BOB_POINTS, BOB_AMOUNT, bobProof);
        _assertEq(token.balanceOf(BOB), BOB_AMOUNT, "bob allocation");

        TradeProofSeasonAllocation.Distribution memory distribution =
            allocation.getDistribution(0);
        _assertEq(distribution.claimedAmount, 10_000_000 * 1e18, "all claimed");
        _assertEq(
            uint256(distribution.state),
            uint256(TradeProofSeasonAllocation.DistributionState.Completed),
            "completed state"
        );
        _assertEq(token.balanceOf(address(allocation)), 0, "allocation exhausted");
    }

    function testRelayerCanSubmitButTokensOnlyReachClaimAccount() public {
        _closeSeasonZeroWithPoints();
        (bytes32 root,, bytes32 bobLeaf) = _genesisRoot(1);
        _proposeFundAndActivateGenesis(root);
        bytes32[] memory proof = new bytes32[](1);
        proof[0] = bobLeaf;

        vm.prank(RELAYER);
        allocation.claim(0, ALICE, ALICE_POINTS, ALICE_AMOUNT, proof);
        _assertEq(token.balanceOf(RELAYER), 0, "relayer receives nothing");
        _assertEq(token.balanceOf(ALICE), ALICE_AMOUNT, "account receives claim");
    }

    function testDoubleClaimIsRejected() public {
        _closeSeasonZeroWithPoints();
        (bytes32 root,, bytes32 bobLeaf) = _genesisRoot(1);
        _proposeFundAndActivateGenesis(root);
        bytes32[] memory proof = new bytes32[](1);
        proof[0] = bobLeaf;
        allocation.claim(0, ALICE, ALICE_POINTS, ALICE_AMOUNT, proof);

        vm.expectRevert(
            abi.encodeWithSelector(
                TradeProofSeasonAllocation.AlreadyClaimed.selector, 0, ALICE
            )
        );
        allocation.claim(0, ALICE, ALICE_POINTS, ALICE_AMOUNT, proof);
    }

    function testClaimMustMatchClosedOnchainPointsSnapshot() public {
        _closeSeasonZeroWithPoints();
        (bytes32 root,, bytes32 bobLeaf) = _genesisRoot(1);
        _proposeFundAndActivateGenesis(root);
        bytes32[] memory proof = new bytes32[](1);
        proof[0] = bobLeaf;

        vm.expectRevert(
            abi.encodeWithSelector(
                TradeProofSeasonAllocation.PointsSnapshotMismatch.selector,
                ALICE,
                ALICE_POINTS + 1,
                ALICE_POINTS
            )
        );
        allocation.claim(0, ALICE, ALICE_POINTS + 1, ALICE_AMOUNT, proof);
    }

    function testWalletBelowMinimumPointsCannotClaim() public {
        _closeSeasonZeroWithPoints();
        uint32 revision = 1;
        uint256 amount = 10_000_000 * 1e18;
        bytes32 carolLeaf = allocation.claimLeaf(0, revision, CAROL, 0, amount);
        vm.prank(PUBLISHER);
        allocation.proposeSeason(0, carolLeaf, DATASET_DIGEST, 1, amount);
        vm.prank(PUBLISHER);
        allocation.fundSeason(0);
        TradeProofSeasonAllocation.Distribution memory distribution =
            allocation.getDistribution(0);
        vm.warp(distribution.claimableAt);
        allocation.activateSeason(0);

        bytes32[] memory proof = new bytes32[](0);
        vm.expectRevert(
            abi.encodeWithSelector(
                TradeProofSeasonAllocation.IneligiblePoints.selector,
                CAROL,
                0,
                25
            )
        );
        allocation.claim(0, CAROL, 0, amount, proof);
    }

    function testInvalidMerkleProofIsRejected() public {
        _closeSeasonZeroWithPoints();
        (bytes32 root,,) = _genesisRoot(1);
        _proposeFundAndActivateGenesis(root);
        bytes32[] memory wrongProof = new bytes32[](1);
        wrongProof[0] = bytes32(uint256(0xBAD));

        vm.expectRevert(
            abi.encodeWithSelector(
                TradeProofSeasonAllocation.InvalidMerkleProof.selector, 0, ALICE
            )
        );
        allocation.claim(0, ALICE, ALICE_POINTS, ALICE_AMOUNT, wrongProof);
    }

    function testCancelledProposalRefundsTreasuryAndAllowsNewRevision() public {
        _closeSeasonZeroWithPoints();
        (bytes32 root,,) = _genesisRoot(1);
        _proposeGenesis(root);
        vm.prank(PUBLISHER);
        allocation.fundSeason(0);
        uint256 treasuryBeforeCancel = token.balanceOf(COMMUNITY);

        vm.prank(PUBLISHER);
        allocation.cancelProposedSeason(0, CANCEL_REASON);
        _assertEq(
            token.balanceOf(COMMUNITY),
            treasuryBeforeCancel + 10_000_000 * 1e18,
            "treasury refunded"
        );
        _assertEq(allocation.totalCommunityCommitted(), 0, "commitment released");

        (bytes32 revisionTwoRoot,,) = _genesisRoot(2);
        vm.prank(PUBLISHER);
        allocation.proposeSeason(
            0, revisionTwoRoot, bytes32(uint256(0xDA7B)), 2, 10_000_000 * 1e18
        );
        TradeProofSeasonAllocation.Distribution memory distribution =
            allocation.getDistribution(0);
        _assertEq(distribution.revision, 2, "revision incremented");
    }

    function testActiveDistributionCannotBeCancelledOrReplaced() public {
        _closeSeasonZeroWithPoints();
        (bytes32 root,,) = _genesisRoot(1);
        _proposeFundAndActivateGenesis(root);

        vm.expectRevert(
            abi.encodeWithSelector(
                TradeProofSeasonAllocation.DistributionNotProposed.selector,
                0,
                TradeProofSeasonAllocation.DistributionState.Active
            )
        );
        vm.prank(PUBLISHER);
        allocation.cancelProposedSeason(0, CANCEL_REASON);

        vm.expectRevert(
            abi.encodeWithSelector(
                TradeProofSeasonAllocation.DistributionAlreadyExists.selector,
                0,
                TradeProofSeasonAllocation.DistributionState.Active
            )
        );
        vm.prank(PUBLISHER);
        allocation.proposeSeason(0, root, DATASET_DIGEST, 2, 10_000_000 * 1e18);
    }

    function testAggregateFundingCannotExceedCommunityAllocation() public {
        vm.warp(contribution.seasonClosableAt(2));
        contribution.closeSeason(1);
        contribution.closeSeason(2);

        uint256 firstAmount = 449_999_999 * 1e18;
        vm.prank(PUBLISHER);
        allocation.proposeSeason(
            1, bytes32(uint256(0xA1)), bytes32(uint256(0xD1)), 1, firstAmount
        );
        vm.prank(PUBLISHER);
        allocation.fundSeason(1);

        uint256 secondAmount = 2 * 1e18;
        vm.prank(PUBLISHER);
        allocation.proposeSeason(
            2, bytes32(uint256(0xA2)), bytes32(uint256(0xD2)), 1, secondAmount
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                TradeProofSeasonAllocation.CommunityAllocationExceeded.selector,
                450_000_001 * 1e18,
                450_000_000 * 1e18
            )
        );
        vm.prank(PUBLISHER);
        allocation.fundSeason(2);
    }

    function testClaimLeafIsDomainSeparatedByRevisionContractAndChain() public view {
        bytes32 first = allocation.claimLeaf(0, 1, ALICE, ALICE_POINTS, ALICE_AMOUNT);
        bytes32 second = allocation.claimLeaf(0, 2, ALICE, ALICE_POINTS, ALICE_AMOUNT);
        _assertTrue(first != second, "revision domain separation");

        TradeProofSeasonAllocation another =
            new TradeProofSeasonAllocation(token, contribution, PUBLISHER, COMMUNITY);
        bytes32 otherContract = another.claimLeaf(0, 1, ALICE, ALICE_POINTS, ALICE_AMOUNT);
        _assertTrue(first != otherContract, "contract domain separation");
    }

    function testNoOwnerRootRewriteOrTreasurySweepSurfaceExists() public {
        (bool ownerSuccess,) = address(allocation).call(abi.encodeWithSignature("owner()"));
        (bool rewriteSuccess,) = address(allocation).call(
            abi.encodeWithSignature("setMerkleRoot(uint32,bytes32)", 0, bytes32(uint256(1)))
        );
        (bool sweepSuccess,) =
            address(allocation).call(abi.encodeWithSignature("sweep(address,uint256)", ALICE, 1));
        _assertFalse(ownerSuccess, "owner surface");
        _assertFalse(rewriteSuccess, "root rewrite surface");
        _assertFalse(sweepSuccess, "treasury sweep surface");
    }

    function _closeSeasonZeroWithPoints() private {
        vm.prank(ALICE);
        bytes32 aliceReceipt = contribution.submitPublicGoodsContribution(
            TradeProofContribution.ContributionKind.DocumentationTranslationOrEducation,
            bytes32(uint256(0xA11CE)),
            uint32(ALICE_POINTS)
        );
        vm.prank(BOB);
        bytes32 bobReceipt = contribution.submitPublicGoodsContribution(
            TradeProofContribution.ContributionKind.DocumentationTranslationOrEducation,
            bytes32(uint256(0xB0B)),
            uint32(BOB_POINTS)
        );
        contribution.reviewPublicGoodsContribution(
            aliceReceipt, true, uint32(ALICE_POINTS), bytes32(uint256(0xA1))
        );
        contribution.reviewPublicGoodsContribution(
            bobReceipt, true, uint32(BOB_POINTS), bytes32(uint256(0xB1))
        );
        TradeProofContribution.Receipt memory alice = contribution.getReceipt(aliceReceipt);
        vm.warp(alice.eligibleAt);
        contribution.finalizeReceipt(aliceReceipt);
        contribution.finalizeReceipt(bobReceipt);
        vm.warp(contribution.seasonClosableAt(0));
        contribution.closeSeason(0);
    }

    function _genesisRoot(uint32 revision)
        private
        view
        returns (bytes32 root, bytes32 aliceLeaf, bytes32 bobLeaf)
    {
        aliceLeaf = allocation.claimLeaf(0, revision, ALICE, ALICE_POINTS, ALICE_AMOUNT);
        bobLeaf = allocation.claimLeaf(0, revision, BOB, BOB_POINTS, BOB_AMOUNT);
        root = _hashPair(aliceLeaf, bobLeaf);
    }

    function _proposeGenesis(bytes32 root) private {
        vm.prank(PUBLISHER);
        allocation.proposeSeason(0, root, DATASET_DIGEST, 2, 10_000_000 * 1e18);
    }

    function _proposeFundAndActivateGenesis(bytes32 root) private {
        _proposeGenesis(root);
        vm.prank(PUBLISHER);
        allocation.fundSeason(0);
        TradeProofSeasonAllocation.Distribution memory distribution =
            allocation.getDistribution(0);
        vm.warp(distribution.claimableAt);
        allocation.activateSeason(0);
    }

    function _hashPair(bytes32 first, bytes32 second) private pure returns (bytes32) {
        return first < second
            ? keccak256(abi.encodePacked(first, second))
            : keccak256(abi.encodePacked(second, first));
    }

    function _assertTrue(bool value, string memory message) private pure {
        require(value, message);
    }

    function _assertFalse(bool value, string memory message) private pure {
        require(!value, message);
    }

    function _assertEq(uint256 left, uint256 right, string memory message) private pure {
        require(left == right, message);
    }
}
