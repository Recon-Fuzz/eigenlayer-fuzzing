// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import {EigenLayerSetup} from "src/test/recon/EigenLayerSetup.sol";
import "src/test/recon/MockERC20.sol";
import "forge-std/Test.sol";

contract EigenLayerSetupTest is EigenLayerSetup, Test {
    MockERC20 stETH;
    MockERC20 cbETH;

    address[] public tokenAddressArray = new address[](2);

    // TODO: add tests here to verify deployments
    function test_deployEigenLayer() public {
        stETH = new MockERC20("Staked ETH", "stETH", 18);
        cbETH = new MockERC20("Coinbase ETH", "cbETH", 18);

        tokenAddressArray[0] = address(stETH);
        tokenAddressArray[1] = address(cbETH);

        deployEigenLayer(tokenAddressArray);
    }
}
