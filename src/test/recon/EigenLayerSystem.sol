// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "forge-std/Test.sol";

import {EigenLayerSetup} from "./EigenLayerSetup.sol";
import {IStrategy} from "../../contracts/interfaces/IStrategy.sol";

contract EigenLayerSystem is EigenLayerSetup, Test {
    address immutable TOKEN_BURN_ADDRESS = address(0xDEADBEEF); // address for simulating token burning for tokens that don't allow transfer to 0 address

    /// @notice simulates a native slashing event on a validator
    /// @dev when calling this through a target function, need to prank as the pod's address to allow modifying balances in EigenPodManager
    /// @param podOwner the owner of the pod being slashed
    function slashNative(address podOwner) public {
        address pod = getPodForOwner(address(podOwner));

        // reduces the balance of the deposit contract by the max slashing penalty (1 ETH)
        ethPOSDepositMock.slash(1 ether);

        // update the OperatorDelegator's share balance in EL by calling EigenPodManager as the pod
        vm.prank(pod);
        eigenPodManager.recordBeaconChainETHBalanceUpdate(podOwner, -1 ether);
    }

    /// @notice simulates an AVS slashing event
    /// @dev this assumes slashing amounts for an LST and native ETH can be different
    function slashAVS(address user, uint256 nativeSlashAmount, uint256 lstSlashAmount) public {
        // Slash native ETH if user has any staked in an EigenPod
        uint256 nativeEthShares = uint256(eigenPodManager.podOwnerShares(address(user)));
        if (nativeEthShares > 0) {
            // user can be slashed a max amount of their entire stake
            nativeSlashAmount = nativeSlashAmount % nativeEthShares;

            // shares are 1:1 with ETH in EigenPod so can slash the share amount directly
            ethPOSDepositMock.slash(nativeSlashAmount);

            // update the OperatorDelegator's share balance in EL by calling EigenPodManager as the pod
            address podAddress = getPodForOwner(user);
            vm.prank(podAddress);
            eigenPodManager.recordBeaconChainETHBalanceUpdate(address(user), -int256(nativeSlashAmount));
        }

        // loop through strategies to slash if a user has any shares in them
        for (uint256 i; i < deployedStrategyArray.length; i++) {
            IStrategy strategy = IStrategy(address(deployedStrategyArray[i]));
            uint256 lstShares = strategy.shares(address(user));

            // Slash LST if user has any shares of the given LST strategy
            if (lstShares > 0) {
                uint256 slashingAmountLSTShares = lstSlashAmount % lstShares;
                uint256 amountLSTToken = strategy.sharesToUnderlyingView(slashingAmountLSTShares);

                // "burn" tokens in strategy to ensure they don't effect accounting
                vm.prank(address(deployedStrategyArray[i]));
                IERC20 underlyingToken = strategy.underlyingToken();
                underlyingToken.transfer(TOKEN_BURN_ADDRESS, amountLSTToken);

                // remove shares to update user's accounting
                vm.prank(address(delegation));
                strategyManager.removeShares(address(user), strategy, slashingAmountLSTShares);
            }
        }
    }

    /// @notice returns the address of an EigenPod for an Owner, if one exists
    function getPodForOwner(address owner) public view returns (address eigenPod) {
        return address(eigenPodManager.getPod(address(owner)));
    }
}
