// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.0;

import {BaseTargetFunctions} from "@chimera/BaseTargetFunctions.sol";
import {BeforeAfter} from "./BeforeAfter.sol";
import {Properties} from "./Properties.sol";
import {vm} from "@chimera/Hevm.sol";

abstract contract PodTargetFunctions is BaseTargetFunctions, Properties, BeforeAfter {
    function eigenPod_activateRestaking() public {
        eigenPod.activateRestaking();
    }

    function eigenPod_recoverTokens(
        address[] calldata tokenList,
        uint256[] calldata amountsToWithdraw,
        address recipient
    ) public {
        eigenPod.recoverTokens(IERC20[](tokenList), amountsToWithdraw, recipient);
    }

    function eigenPod_stake(bytes calldata pubkey, bytes calldata signature, bytes32 depositDataRoot) public {
        eigenPod.stake(pubkey, signature, depositDataRoot);
    }

    function eigenPod_verifyAndProcessWithdrawals(
        uint64 oracleTimestamp,
        BeaconChainProofs.StateRootProof calldata stateRootProof,
        BeaconChainProofs.WithdrawalProof[] calldata withdrawalProofs,
        bytes[] calldata validatorFieldsProofs,
        bytes32[][] calldata validatorFields,
        bytes32[][] calldata withdrawalFields
    ) public {
        eigenPod.verifyAndProcessWithdrawals(
            oracleTimestamp,
            BeaconChainProofs.StateRootProof(stateRootProof),
            BeaconChainProofs.WithdrawalProof[](withdrawalProofs),
            validatorFieldsProofs,
            validatorFields,
            withdrawalFields
        );
    }

    function eigenPod_verifyBalanceUpdates(
        uint64 oracleTimestamp,
        uint40[] calldata validatorIndices,
        BeaconChainProofs.StateRootProof calldata stateRootProof,
        bytes[] calldata validatorFieldsProofs,
        bytes32[][] calldata validatorFields
    ) public {
        eigenPod.verifyBalanceUpdates(
            oracleTimestamp,
            validatorIndices,
            BeaconChainProofs.StateRootProof(stateRootProof),
            validatorFieldsProofs,
            validatorFields
        );
    }

    function eigenPod_verifyWithdrawalCredentials(
        uint64 oracleTimestamp,
        BeaconChainProofs.StateRootProof calldata stateRootProof,
        uint40[] calldata validatorIndices,
        bytes[] calldata validatorFieldsProofs,
        bytes32[][] calldata validatorFields
    ) public {
        eigenPod.verifyWithdrawalCredentials(
            oracleTimestamp,
            BeaconChainProofs.StateRootProof(stateRootProof),
            validatorIndices,
            validatorFieldsProofs,
            validatorFields
        );
    }

    function eigenPod_withdrawBeforeRestaking() public {
        eigenPod.withdrawBeforeRestaking();
    }

    function eigenPod_withdrawNonBeaconChainETHBalanceWei(address recipient, uint256 amountToWithdraw) public {
        eigenPod.withdrawNonBeaconChainETHBalanceWei(recipient, amountToWithdraw);
    }

    function eigenPod_withdrawRestakedBeaconChainETH(address recipient, uint256 amountWei) public {
        eigenPod.withdrawRestakedBeaconChainETH(recipient, amountWei);
    }
}
