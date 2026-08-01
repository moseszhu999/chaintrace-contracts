// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

interface IERC20TestnetTreasury {
    function transfer(address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
}

/// @title TradeProof Testnet Treasury Vault
/// @notice Explicitly centralized vault for Base Sepolia economic-stack demonstrations only.
/// @dev Production treasury custody requires separately reviewed multisig and timelock contracts.
contract TradeProofTestnetTreasuryVault {
    address public immutable operator;
    bytes32 public immutable purposeHash;

    error NotOperator(address caller);
    error ZeroAddress();
    error ZeroPurposeHash();
    error TokenOperationFailed();

    event TokenApproved(
        address indexed token, address indexed spender, uint256 amount, bytes32 indexed purposeHash
    );
    event TokenTransferred(
        address indexed token,
        address indexed recipient,
        uint256 amount,
        bytes32 indexed purposeHash
    );

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator(msg.sender);
        _;
    }

    constructor(address operator_, bytes32 purposeHash_) {
        if (operator_ == address(0)) revert ZeroAddress();
        if (purposeHash_ == bytes32(0)) revert ZeroPurposeHash();
        operator = operator_;
        purposeHash = purposeHash_;
    }

    function approveToken(address token, address spender, uint256 amount) external onlyOperator {
        if (token == address(0) || spender == address(0)) revert ZeroAddress();
        if (!IERC20TestnetTreasury(token).approve(spender, amount)) revert TokenOperationFailed();
        emit TokenApproved(token, spender, amount, purposeHash);
    }

    function transferToken(address token, address recipient, uint256 amount) external onlyOperator {
        if (token == address(0) || recipient == address(0)) revert ZeroAddress();
        if (!IERC20TestnetTreasury(token).transfer(recipient, amount)) {
            revert TokenOperationFailed();
        }
        emit TokenTransferred(token, recipient, amount, purposeHash);
    }
}
