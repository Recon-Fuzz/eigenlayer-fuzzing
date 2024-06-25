// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "forge-std/console.sol";

import {EigenLayerSystem} from "./EigenLayerSystem.sol";
import {IStrategy} from "../../../src/contracts/interfaces/IStrategy.sol";

contract EigenLayerSystemTest is EigenLayerSystem {
    using SafeERC20 for IERC20;

    function test_deployEigenLayer_local() public {
        deployEigenLayerLocal();
    }

    function test_slash_native() public {
        deployEigenLayerLocal();
        vm.deal(address(this), 32 ether);

        // setting up EigenPod to be slashable
        eigenPodManager.createPod();
        bytes memory pubkey = hex"123456";
        bytes memory signature = hex"789101";
        bytes32 dataRoot = bytes32(uint256(0xbeef));
        eigenPodManager.stake{value: 32 ether}(pubkey, signature, dataRoot);
        address pod = getPodForOwner(address(this));
        vm.prank(pod);
        eigenPodManager.recordBeaconChainETHBalanceUpdate(address(this), 32 ether);

        uint256 depositContractBalanceBefore = address(ethPOSDepositMock).balance;
        int256 podOwnerSharesBefore = eigenPodManager.podOwnerShares(address(this));

        // slash the created EigenPod
        slashNative(address(this));

        uint256 depositContractBalanceAfter = address(ethPOSDepositMock).balance;
        int256 podOwnerSharesAfter = eigenPodManager.podOwnerShares(address(this));

        assertTrue(
            depositContractBalanceBefore > depositContractBalanceAfter,
            "deposit contract balance doesn't decrease"
        );
        assertTrue(podOwnerSharesBefore > podOwnerSharesAfter, "pod owner shares don't decrease");
    }

    function test_slash_avs() public {
        deployEigenLayerLocal();

        vm.deal(address(this), 32 ether);
        stETH.mint(address(this), 32 ether);
        stETH.approve(address(strategyManager), type(uint256).max);

        // deposit into strategy
        IStrategy strategyToDeposit = IStrategy(address(deployedStrategyArray[0]));
        strategyManager.depositIntoStrategy(strategyToDeposit, IERC20(address(stETH)), 12 ether);

        // setting up EigenPod to be slashable
        eigenPodManager.createPod();
        bytes memory pubkey = hex"123456";
        bytes memory signature = hex"789101";
        bytes32 dataRoot = bytes32(uint256(0xbeef));
        eigenPodManager.stake{value: 32 ether}(pubkey, signature, dataRoot);
        address pod = getPodForOwner(address(this));
        vm.prank(pod);
        eigenPodManager.recordBeaconChainETHBalanceUpdate(address(this), 32 ether);

        uint256 depositContractBalanceBefore = address(ethPOSDepositMock).balance;
        int256 podOwnerSharesBefore = eigenPodManager.podOwnerShares(address(this));
        (, uint256[] memory LSTsharesBefore) = strategyManager.getDeposits(address(this));

        // slash the user's deposited balance across native and LSTs
        slashAVS(address(this), 5 ether, 5 ether);

        uint256 depositContractBalanceAfter = address(ethPOSDepositMock).balance;
        int256 podOwnerSharesAfter = eigenPodManager.podOwnerShares(address(this));
        (, uint256[] memory LSTsharesafter) = strategyManager.getDeposits(address(this));

        assertTrue(
            depositContractBalanceBefore > depositContractBalanceAfter,
            "deposit contract balance doesn't decrease"
        );
        assertTrue(podOwnerSharesBefore > podOwnerSharesAfter, "pod owner shares don't decrease");
        assertTrue(LSTsharesBefore[0] > LSTsharesafter[0], "LST shares don't decrease");
    }
}
