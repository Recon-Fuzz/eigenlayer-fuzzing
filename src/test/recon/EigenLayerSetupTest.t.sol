// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import {EigenLayerSetup} from "src/test/recon/EigenLayerSetup.sol";
import "forge-std/Test.sol";

contract EigenLayerSetupTest is EigenLayerSetup, Test {
    function test_deployEigenLayer() public {
        deployEigenLayer();
    }
}
