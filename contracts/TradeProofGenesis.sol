// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { TradeProofToken } from "./TradeProofToken.sol";
import { TradeProofTeamVesting, ITradeProofToken } from "./TradeProofTeamVesting.sol";

/// @title TradeProof Genesis
/// @notice Atomically deploys fixed-supply TPROOF and moves the entire team allocation into vesting.
/// @dev The factory retains no token balance and exposes no post-deployment control functions.
contract TradeProofGenesis {
    TradeProofToken public immutable token;
    TradeProofTeamVesting public immutable teamVesting;

    error ZeroAddress();
    error DuplicateBeneficiary(address beneficiary);
    error TeamAllocationTransferFailed();
    error GenesisInvariantFailed();

    event GenesisDeployed(
        address indexed token,
        address indexed teamVesting,
        address indexed teamBeneficiary,
        uint64 vestingStart
    );

    constructor(
        address communityTreasury,
        address ecosystemTreasury,
        address teamBeneficiary,
        address adoptionTreasury,
        address liquidityReserve,
        address securityReserve,
        uint64 vestingStart
    ) {
        _validateBeneficiaries(
            communityTreasury,
            ecosystemTreasury,
            teamBeneficiary,
            adoptionTreasury,
            liquidityReserve,
            securityReserve
        );

        TradeProofToken deployedToken = new TradeProofToken(
            communityTreasury,
            ecosystemTreasury,
            address(this),
            adoptionTreasury,
            liquidityReserve,
            securityReserve
        );
        TradeProofTeamVesting deployedVesting = new TradeProofTeamVesting(
            ITradeProofToken(address(deployedToken)), teamBeneficiary, vestingStart
        );

        if (!deployedToken.transfer(address(deployedVesting), deployedToken.TEAM_ALLOCATION())) {
            revert TeamAllocationTransferFailed();
        }
        if (
            deployedToken.balanceOf(address(this)) != 0
                || deployedToken.balanceOf(address(deployedVesting)) != deployedToken.TEAM_ALLOCATION()
                || deployedToken.totalSupply() != deployedToken.MAX_SUPPLY()
        ) {
            revert GenesisInvariantFailed();
        }

        token = deployedToken;
        teamVesting = deployedVesting;
        emit GenesisDeployed(address(deployedToken), address(deployedVesting), teamBeneficiary, vestingStart);
    }

    function _validateBeneficiaries(
        address communityTreasury,
        address ecosystemTreasury,
        address teamBeneficiary,
        address adoptionTreasury,
        address liquidityReserve,
        address securityReserve
    ) private pure {
        address[6] memory beneficiaries = [
            communityTreasury,
            ecosystemTreasury,
            teamBeneficiary,
            adoptionTreasury,
            liquidityReserve,
            securityReserve
        ];
        for (uint256 index = 0; index < beneficiaries.length; index++) {
            address beneficiary = beneficiaries[index];
            if (beneficiary == address(0)) revert ZeroAddress();
            for (uint256 prior = 0; prior < index; prior++) {
                if (beneficiary == beneficiaries[prior]) {
                    revert DuplicateBeneficiary(beneficiary);
                }
            }
        }
    }
}
