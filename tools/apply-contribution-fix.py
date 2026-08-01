from pathlib import Path

contract_path = Path("contracts/TradeProofContribution.sol")
contract_source = contract_path.read_text(encoding="utf-8")
contract_source = contract_source.replace(
    "/// @notice Freeze a season after its review and appeal windows have elapsed.",
    "/// @notice Permanently close a season after its review and appeal windows have elapsed.",
)
contract_path.write_text(contract_source, encoding="utf-8")

test_path = Path("test/TradeProofContribution.t.sol")
test_source = test_path.read_text(encoding="utf-8")

replacements = {
    "vm.expectRevert(TradeProofContribution.ReviewDelayActive.selector);": '''vm.expectRevert(
            abi.encodeWithSelector(
                TradeProofContribution.ReviewDelayActive.selector, receiptId, receipt.eligibleAt
            )
        );''',
    "vm.expectRevert(TradeProofContribution.DuplicateRole.selector);": '''vm.expectRevert(
            abi.encodeWithSelector(
                TradeProofContribution.DuplicateRole.selector, bytes32("buyer")
            )
        );''',
    "vm.expectRevert(TradeProofContribution.ViralReuseWindowMissed.selector);": '''vm.expectRevert(
            abi.encodeWithSelector(
                TradeProofContribution.ViralReuseWindowMissed.selector,
                RESPONSE_A,
                PASSPORT_B
            )
        );''',
    "vm.expectRevert(TradeProofContribution.PointsOutOfRange.selector);": '''vm.expectRevert(
            abi.encodeWithSelector(
                TradeProofContribution.PointsOutOfRange.selector, 15001, 500, 15000
            )
        );''',
    '''        vm.expectRevert(TradeProofContribution.PairSeasonCapExceeded.selector);
        contribution.recordIndependentResponse(eleventhResponse);''': '''        bytes32 pairKey = uint160(ALICE) < uint160(BOB)
            ? keccak256(abi.encode(ALICE, BOB))
            : keccak256(abi.encode(BOB, ALICE));
        vm.expectRevert(
            abi.encodeWithSelector(
                TradeProofContribution.PairSeasonCapExceeded.selector, pairKey, 330
            )
        );
        contribution.recordIndependentResponse(eleventhResponse);''',
    "bytes32 pairKey = keccak256(abi.encode(ALICE, BOB));": '''bytes32 pairKey = uint160(ALICE) < uint160(BOB)
            ? keccak256(abi.encode(ALICE, BOB))
            : keccak256(abi.encode(BOB, ALICE));''',
}

for old, new in replacements.items():
    if old in test_source:
        test_source = test_source.replace(old, new, 1)

test_path.write_text(test_source, encoding="utf-8")
