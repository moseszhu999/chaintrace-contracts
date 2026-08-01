// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { TradeProofGenesis } from "../contracts/TradeProofGenesis.sol";
import { TradeProofToken } from "../contracts/TradeProofToken.sol";
import { TradeProofTeamVesting, ITradeProofToken } from "../contracts/TradeProofTeamVesting.sol";

interface VmToken {
    function prank(address caller) external;
    function expectRevert(bytes calldata revertData) external;
    function expectRevert(bytes4 selector) external;
    function warp(uint256 timestamp) external;
}

contract TradeProofTokenTest {
    VmToken private constant vm = VmToken(address(uint160(uint256(keccak256("hevm cheat code")))));

    address private constant COMMUNITY = address(0xC011);
    address private constant ECOSYSTEM = address(0xEC05);
    address private constant TEAM = address(0x7EAA);
    address private constant ADOPTION = address(0xAD07);
    address private constant LIQUIDITY = address(0x110D);
    address private constant SECURITY = address(0x5EC);
    address private constant ALICE = address(0xA11CE);
    address private constant BOB = address(0xB0B);

    TradeProofGenesis private genesis;
    TradeProofToken private token;
    TradeProofTeamVesting private vesting;
    uint64 private vestingStart;

    function setUp() public {
        vestingStart = uint64(block.timestamp + 1 days);
        genesis = new TradeProofGenesis(
            COMMUNITY,
            ECOSYSTEM,
            TEAM,
            ADOPTION,
            LIQUIDITY,
            SECURITY,
            vestingStart
        );
        token = genesis.token();
        vesting = genesis.teamVesting();
    }

    function testGenesisCreatesExactlyOneBillionFixedSupply() public view {
        _assertEq(token.totalSupply(), 1_000_000_000 * 1e18, "total supply");
        _assertEq(token.MAX_SUPPLY(), token.totalSupply(), "maximum supply");
        _assertEq(token.decimals(), 18, "decimals");
        _assertEq(keccak256(bytes(token.name())), keccak256("TradeProof Token"), "name");
        _assertEq(keccak256(bytes(token.symbol())), keccak256("TPROOF"), "symbol");
    }

    function testGenesisAllocationsMatchEconomicConstitution() public view {
        _assertEq(token.balanceOf(COMMUNITY), 450_000_000 * 1e18, "community");
        _assertEq(token.balanceOf(ECOSYSTEM), 200_000_000 * 1e18, "ecosystem");
        _assertEq(token.balanceOf(address(vesting)), 150_000_000 * 1e18, "team vesting");
        _assertEq(token.balanceOf(ADOPTION), 100_000_000 * 1e18, "adoption");
        _assertEq(token.balanceOf(LIQUIDITY), 50_000_000 * 1e18, "liquidity reserve");
        _assertEq(token.balanceOf(SECURITY), 50_000_000 * 1e18, "security reserve");
    }

    function testGenesisFactoryRetainsNoTokensOrControlBalance() public view {
        _assertEq(token.balanceOf(address(genesis)), 0, "factory balance");
        _assertEq(address(vesting.token()), address(token), "vesting token");
        _assertEq(vesting.beneficiary(), TEAM, "team beneficiary");
        _assertEq(vesting.startTimestamp(), vestingStart, "vesting start");
    }

    function testTransferMovesExactAmountWithoutFee() public {
        uint256 amount = 1_234 * 1e18;
        vm.prank(COMMUNITY);
        _assertTrue(token.transfer(ALICE, amount), "transfer result");
        _assertEq(token.balanceOf(ALICE), amount, "recipient exact amount");
        _assertEq(
            token.balanceOf(COMMUNITY),
            token.COMMUNITY_ALLOCATION() - amount,
            "sender exact deduction"
        );
        _assertEq(token.totalSupply(), token.MAX_SUPPLY(), "supply unchanged");
    }

    function testApproveAndTransferFromUseStandardAllowance() public {
        uint256 approved = 500 * 1e18;
        uint256 spent = 120 * 1e18;
        vm.prank(COMMUNITY);
        _assertTrue(token.approve(ALICE, approved), "approve result");

        vm.prank(ALICE);
        _assertTrue(token.transferFrom(COMMUNITY, BOB, spent), "transferFrom result");
        _assertEq(token.balanceOf(BOB), spent, "recipient balance");
        _assertEq(token.allowance(COMMUNITY, ALICE), approved - spent, "remaining allowance");
    }

    function testMaximumAllowanceDoesNotDecrease() public {
        vm.prank(COMMUNITY);
        token.approve(ALICE, type(uint256).max);
        vm.prank(ALICE);
        token.transferFrom(COMMUNITY, BOB, 1e18);
        _assertEq(token.allowance(COMMUNITY, ALICE), type(uint256).max, "maximum allowance");
    }

    function testInsufficientBalanceIsRejected() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                TradeProofToken.InsufficientBalance.selector, ALICE, 0, 1
            )
        );
        vm.prank(ALICE);
        token.transfer(BOB, 1);
    }

    function testInsufficientAllowanceIsRejected() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                TradeProofToken.InsufficientAllowance.selector, COMMUNITY, ALICE, 0, 1
            )
        );
        vm.prank(ALICE);
        token.transferFrom(COMMUNITY, BOB, 1);
    }

    function testZeroAddressTransferAndApprovalAreRejected() public {
        vm.expectRevert(TradeProofToken.ZeroAddress.selector);
        vm.prank(COMMUNITY);
        token.transfer(address(0), 1);

        vm.expectRevert(TradeProofToken.ZeroAddress.selector);
        vm.prank(COMMUNITY);
        token.approve(address(0), 1);
    }

    function testNoMintOwnerTaxOrAdministrativeControlSurfaceExists() public {
        (bool mintSuccess,) =
            address(token).call(abi.encodeWithSignature("mint(address,uint256)", ALICE, 1e18));
        (bool ownerSuccess,) = address(token).call(abi.encodeWithSignature("owner()"));
        (bool taxSuccess,) = address(token).call(abi.encodeWithSignature("setTax(uint256)", 1));
        (bool forcedTransferSuccess,) = address(token).call(
            abi.encodeWithSignature("forceTransfer(address,address,uint256)", COMMUNITY, ALICE, 1)
        );
        _assertFalse(mintSuccess, "mint surface");
        _assertFalse(ownerSuccess, "owner surface");
        _assertFalse(taxSuccess, "tax surface");
        _assertFalse(forcedTransferSuccess, "forced transfer surface");
    }

    function testTeamTokensRemainUnavailableBeforeCliff() public {
        vm.warp(uint256(vestingStart) + 365 days - 1);
        _assertEq(vesting.vestedAmount(uint64(block.timestamp)), 0, "vested before cliff");
        _assertEq(vesting.releasable(), 0, "releasable before cliff");
        vm.expectRevert(TradeProofTeamVesting.NothingToRelease.selector);
        vesting.release();
    }

    function testTwelveMonthCliffReleasesTwentyFivePercent() public {
        vm.warp(uint256(vestingStart) + 365 days);
        uint256 expected = 37_500_000 * 1e18;
        _assertEq(vesting.vestedAmount(uint64(block.timestamp)), expected, "cliff vested");
        _assertEq(vesting.release(), expected, "cliff release");
        _assertEq(token.balanceOf(TEAM), expected, "team cliff balance");
        _assertEq(vesting.released(), expected, "released accounting");
    }

    function testVestingIsLinearAndFullyReleasedAtFortyEightMonths() public {
        vm.warp(uint256(vestingStart) + 730 days);
        uint256 halfway = 75_000_000 * 1e18;
        _assertEq(vesting.release(), halfway, "halfway release");

        vm.warp(uint256(vestingStart) + 1460 days);
        uint256 remainder = 75_000_000 * 1e18;
        _assertEq(vesting.release(), remainder, "final release");
        _assertEq(token.balanceOf(TEAM), token.TEAM_ALLOCATION(), "team full allocation");
        _assertEq(token.balanceOf(address(vesting)), 0, "vesting empty at end");
    }

    function testAnyoneMayTriggerReleaseButTokensOnlyReachBeneficiary() public {
        vm.warp(uint256(vestingStart) + 365 days);
        vm.prank(ALICE);
        uint256 amount = vesting.release();
        _assertEq(token.balanceOf(ALICE), 0, "caller receives nothing");
        _assertEq(token.balanceOf(TEAM), amount, "beneficiary receives release");
    }

    function testVestingStartCannotBeBackdated() public {
        vm.warp(block.timestamp + 2 days);
        uint64 backdated = uint64(block.timestamp - 1);
        vm.expectRevert(
            abi.encodeWithSelector(
                TradeProofTeamVesting.VestingStartInPast.selector,
                backdated,
                uint64(block.timestamp)
            )
        );
        new TradeProofTeamVesting(ITradeProofToken(address(token)), TEAM, backdated);
    }

    function testGenesisRejectsDuplicateEconomicBeneficiaries() public {
        vm.expectRevert(
            abi.encodeWithSelector(TradeProofGenesis.DuplicateBeneficiary.selector, ECOSYSTEM)
        );
        new TradeProofGenesis(
            COMMUNITY,
            ECOSYSTEM,
            ECOSYSTEM,
            ADOPTION,
            LIQUIDITY,
            SECURITY,
            uint64(block.timestamp)
        );
    }

    function testGenesisRejectsZeroEconomicBeneficiary() public {
        vm.expectRevert(TradeProofGenesis.ZeroAddress.selector);
        new TradeProofGenesis(
            address(0),
            ECOSYSTEM,
            TEAM,
            ADOPTION,
            LIQUIDITY,
            SECURITY,
            uint64(block.timestamp)
        );
    }

    function testDirectTokenDeploymentRejectsDuplicateRecipients() public {
        vm.expectRevert(
            abi.encodeWithSelector(TradeProofToken.DuplicateRecipient.selector, COMMUNITY)
        );
        new TradeProofToken(COMMUNITY, COMMUNITY, TEAM, ADOPTION, LIQUIDITY, SECURITY);
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

    function _assertEq(uint256 left, uint256 right, string memory message) private pure {
        require(left == right, message);
    }

    function _assertEq(bytes32 left, bytes32 right, string memory message) private pure {
        require(left == right, message);
    }
}
