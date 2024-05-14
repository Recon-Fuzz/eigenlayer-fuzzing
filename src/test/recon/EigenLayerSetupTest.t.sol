// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import {EigenLayerSetup} from "src/test/recon/EigenLayerSetup.sol";
import {MockERC20} from "../mocks/MockERC20.sol";
import "forge-std/Test.sol";

contract EigenLayerSetupTest is EigenLayerSetup, Test {
    MockERC20 stETH;
    MockERC20 cbETH;

    address[] public tokenAddressArray = new address[](2);

    function test_deployEigenLayer() public {
        stETH = new MockERC20("Staked ETH", "stETH", 18);
        cbETH = new MockERC20("Coinbase ETH", "cbETH", 18);

        tokenAddressArray[0] = address(stETH);
        tokenAddressArray[1] = address(cbETH);

        deployEigenLayerLocal(tokenAddressArray);
    }

    // function test_deployEigenLayerFork() public {
    //     address[] memory strategyArray = new address[](2);
    //     address cbETHStrategyAddress = address(0x54945180dB7943c0ed0FEE7EdaB2Bd24620256bc);
    //     address stETHStrategyAddress = address(0x93c4b944D05dfe6df7645A86cd2206016c51564D);

    //     strategyArray[0] = cbETHStrategyAddress;
    //     strategyArray[1] = stETHStrategyAddress;

    //     // pass in addresses of the strategies used in Renzo here for accurate forking
    //     // need to include rpc url and block to fork from
    //     deployEigenLayerForked(strategyArray);
    // }
}
