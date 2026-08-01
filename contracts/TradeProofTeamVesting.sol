// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

interface ITradeProofToken {
    function transfer(address to, uint256 amount) external returns (bool);
}

/// @title TradeProof Team Vesting
/// @notice Immutable 12-month cliff and 48-month linear vesting escrow for the team allocation.
contract TradeProofTeamVesting {
    uint64 public constant CLIFF_DURATION = 365 days;
    uint64 public constant VESTING_DURATION = 1460 days;
    uint256 public constant TOTAL_ALLOCATION = 150_000_000 * 1e18;

    ITradeProofToken public immutable token;
    address public immutable beneficiary;
    uint64 public immutable startTimestamp;
    uint256 public released;

    error ZeroAddress();
    error VestingStartInPast(uint64 supplied, uint64 minimum);
    error NothingToRelease();
    error TokenTransferFailed();

    event TokensReleased(address indexed beneficiary, uint256 amount, uint256 totalReleased);

    constructor(ITradeProofToken token_, address beneficiary_, uint64 startTimestamp_) {
        if (address(token_) == address(0) || beneficiary_ == address(0)) revert ZeroAddress();
        uint64 minimumStart = uint64(block.timestamp);
        if (startTimestamp_ < minimumStart) {
            revert VestingStartInPast(startTimestamp_, minimumStart);
        }
        token = token_;
        beneficiary = beneficiary_;
        startTimestamp = startTimestamp_;
    }

    function cliffTimestamp() public view returns (uint64) {
        return startTimestamp + CLIFF_DURATION;
    }

    function endTimestamp() public view returns (uint64) {
        return startTimestamp + VESTING_DURATION;
    }

    function vestedAmount(uint64 timestamp) public view returns (uint256) {
        if (timestamp < cliffTimestamp()) return 0;
        if (timestamp >= endTimestamp()) return TOTAL_ALLOCATION;
        uint256 elapsed = uint256(timestamp - startTimestamp);
        return TOTAL_ALLOCATION * elapsed / VESTING_DURATION;
    }

    function releasable() public view returns (uint256) {
        return vestedAmount(uint64(block.timestamp)) - released;
    }

    /// @notice Anyone may trigger release, but vested tokens always go to the immutable beneficiary.
    function release() external returns (uint256 amount) {
        amount = releasable();
        if (amount == 0) revert NothingToRelease();
        released += amount;
        if (!token.transfer(beneficiary, amount)) revert TokenTransferFailed();
        emit TokensReleased(beneficiary, amount, released);
    }
}
