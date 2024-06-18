// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import {EigenLayerSetupV2} from "./EigenLayerSetupV2.sol";

contract EigenLayerSystem is EigenLayerSetupV2 {
    /// @notice simulates a native slashing event on a validator
    /// @dev when calling this through a target function, need to prank as the pod's address to allow modifying balances in EigenPodManager
    /// @param podOwner the owner of the pod being slashed
    function slashNative(address podOwner) public {
        // update the OperatorDelegator's share balance in EL by calling EigenPodManager as the pod
        eigenPodManager.recordBeaconChainETHBalanceUpdate(podOwner, -1 ether);

        // reduces the balance of the deposit contract by the max slashing penalty (1 ETH)
        ethPOSDepositMock.slash(1 ether);
    }

    /// @notice returns the address of an EigenPod for an Owner, if one exists
    function getPodForOwner(address owner) public view returns (address eigenPod) {
        return address(eigenPodManager.getPod(address(owner)));
    }
}
