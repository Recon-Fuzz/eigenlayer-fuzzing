// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {vm} from "@chimera/Hevm.sol";

import {ETHPOSDepositMock} from "../mocks/ETHDepositMock.sol";
import {Slasher} from "../../../src/contracts/core/Slasher.sol";
import {DelegationManager} from "../../../src/contracts/core/DelegationManager.sol";
import {StrategyManager} from "../../../src/contracts/core/StrategyManager.sol";
import {EigenPod} from "../../../src/contracts/pods/EigenPod.sol";
import {EigenPodManager} from "../../../src/contracts/pods/EigenPodManager.sol";
import {DelayedWithdrawalRouter} from "../../../src/contracts/pods/DelayedWithdrawalRouter.sol";
import {BeaconChainOracleMock} from "../../../src/test/mocks/BeaconChainOracleMock.sol";
import {PauserRegistry} from "../../../src/contracts/permissions/PauserRegistry.sol";
import {StrategyManager} from "../../../src/contracts/core/StrategyManager.sol";
import {StrategyBase} from "../../../src/contracts/strategies/StrategyBase.sol";
import {EmptyContract} from "../../../src/test/mocks/EmptyContract.sol";
import {StrategyBaseTVLLimits} from "../../../src/contracts/strategies/StrategyBaseTVLLimits.sol";
import {IStrategy} from "../../../src/contracts/interfaces/IStrategy.sol";
import {IBeaconChainOracle} from "../../../src/contracts/interfaces/IBeaconChainOracle.sol";

import "forge-std/console2.sol";

// this contract deploys the EigenLayer system for use by an integrating system
// to use, the deployEigenLayer function is called by the setup function in the integrating system's fuzz suite
// which either inherits this contract to have access to the deployed contracts and their state variables
contract EigenLayerSetup {
    struct StrategyConfig {
        uint256 maxDeposits;
        uint256 maxPerDeposit;
        address tokenAddress;
        string tokenSymbol;
    }

    // EigenLayer Contracts
    ProxyAdmin internal eigenLayerProxyAdmin;
    PauserRegistry internal eigenLayerPauserReg;
    Slasher internal slasher;
    Slasher internal slasherImplementation;
    DelegationManager internal delegation;
    DelegationManager internal delegationImplementation;
    StrategyManager internal strategyManager;
    StrategyManager internal strategyManagerImplementation;
    EigenPodManager internal eigenPodManager;
    EigenPodManager internal eigenPodManagerImplementation;
    DelayedWithdrawalRouter internal delayedWithdrawalRouter;
    DelayedWithdrawalRouter internal delayedWithdrawalRouterImplementation;
    UpgradeableBeacon internal eigenPodBeacon;
    EigenPod internal eigenPodImplementation;
    StrategyBase internal baseStrategyImplementation;
    IStrategy[] internal strategies;
    uint256[] internal withdrawalDelayBlocks;
    address[] internal tokenAddresses;

    // addresses for fork testing
    address internal eigenLayerPauserRegAddress;
    address internal delegationAddress;
    address internal strategyManagerAddress;
    address internal slasherAddress;
    address internal eigenPodManagerAddress;
    address internal delayedWithdrawalRouterAddress;
    address internal operationsMultisig;
    address internal executorMultisig;
    address internal beaconChainOracleAddress;
    address internal eigenPodBeaconAddress;
    address internal cbETHStrategyAddress;
    address internal stETHStrategyAddress;

    // strategies deployed
    StrategyBaseTVLLimits[] internal deployedStrategyArray;
    // strategies deployed on mainnet
    StrategyBase[] internal deployedForkStrategyArray;

    EmptyContract internal emptyContract;

    // BeaconChain deposit contract & beacon chain oracle
    ETHPOSDepositMock internal ethPOSDepositMock;
    address internal beaconChainOracle;

    // NOTE: this replaces all multisig accounts in the deployment script
    address admin = address(this);

    // NOTE: All constant values are taken from mainnet deployments
    uint256 MAX_RESTAKED_BALANCE_GWEI_PER_VALIDATOR = 32 gwei;
    uint64 GENESIS_TIME = 1616508000;

    // NOTE: setting these to false so that contracts can immediately be interacted with
    uint256 DELEGATION_INIT_PAUSED_STATUS = 0;
    uint256 DELEGATION_INIT_WITHDRAWAL_DELAY_BLOCKS = 0;
    uint256 STRATEGY_MANAGER_INIT_PAUSED_STATUS = 0;
    uint256 SLASHER_INIT_PAUSED_STATUS = 0;
    uint256 EIGENPOD_MANAGER_INIT_PAUSED_STATUS = 0;
    uint256 DELAYED_WITHDRAWAL_ROUTER_INIT_PAUSED_STATUS = 0;
    uint256 DELAYED_WITHDRAWAL_ROUTER_INIT_WITHDRAWAL_DELAY_BLOCKS = 0;

    /**
        @notice Deploys the entire EigenLayer system locally 
        @dev Strategies are deployed for the tokenAddresses and tokenSymbols passed in
        @param _tokenAddresses The LST addresses to deploy strategies for
        NOTE: This copies the logic of the M1_Deploy script to deploy the entire system
    */
    function deployEigenLayerLocal(address[] memory _tokenAddresses) internal {
        // save tokenAddresses to state
        tokenAddresses = _tokenAddresses;

        // tokens to deploy strategies for
        StrategyConfig[] memory strategyConfigs = new StrategyConfig[](_tokenAddresses.length);

        // deploy proxy admin for ability to upgrade proxy contracts
        vm.prank(admin);
        eigenLayerProxyAdmin = new ProxyAdmin();

        //deploy pauser registry
        {
            address[] memory pausers = new address[](1);
            pausers[0] = admin;
            eigenLayerPauserReg = new PauserRegistry(pausers, admin);
        }

        /** 
            First the upgradeable proxy contracts that will point to implementation contracts get deployed.
            Since implementation contracts aren't yet deployed, they pass in an empty contract as a placeholder
        */
        emptyContract = new EmptyContract();
        delegation = DelegationManager(
            address(new TransparentUpgradeableProxy(address(emptyContract), address(eigenLayerProxyAdmin), ""))
        );
        strategyManager = StrategyManager(
            address(new TransparentUpgradeableProxy(address(emptyContract), address(eigenLayerProxyAdmin), ""))
        );
        slasher = Slasher(
            address(new TransparentUpgradeableProxy(address(emptyContract), address(eigenLayerProxyAdmin), ""))
        );
        eigenPodManager = EigenPodManager(
            address(new TransparentUpgradeableProxy(address(emptyContract), address(eigenLayerProxyAdmin), ""))
        );
        delayedWithdrawalRouter = DelayedWithdrawalRouter(
            address(new TransparentUpgradeableProxy(address(emptyContract), address(eigenLayerProxyAdmin), ""))
        );

        // deploy the ethPOS
        ethPOSDepositMock = new ETHPOSDepositMock();

        // deploy EigenPod
        eigenPodImplementation = new EigenPod(
            ethPOSDepositMock,
            delayedWithdrawalRouter,
            eigenPodManager,
            uint64(MAX_RESTAKED_BALANCE_GWEI_PER_VALIDATOR),
            GENESIS_TIME
        );

        // this is used in EigenPodManager to set the implementation that supplies source bytecode every time a new pod is deployed
        eigenPodBeacon = new UpgradeableBeacon(address(eigenPodImplementation));

        // Second, deploy the *implementation* contracts, using the *proxy contracts* as inputs
        delegationImplementation = new DelegationManager(strategyManager, slasher, eigenPodManager);
        strategyManagerImplementation = new StrategyManager(delegation, eigenPodManager, slasher);
        slasherImplementation = new Slasher(strategyManager, delegation);
        eigenPodManagerImplementation = new EigenPodManager(
            ethPOSDepositMock,
            eigenPodBeacon,
            strategyManager,
            slasher,
            delegation
        );

        delayedWithdrawalRouterImplementation = new DelayedWithdrawalRouter(eigenPodManager);

        // Third, upgrade the proxy contracts to use the correct implementation contracts and initialize them.
        eigenLayerProxyAdmin.upgradeAndCall(
            ITransparentUpgradeableProxy(payable(address(delegation))),
            address(delegationImplementation),
            abi.encodeWithSelector(
                DelegationManager.initialize.selector,
                admin,
                eigenLayerPauserReg,
                DELEGATION_INIT_PAUSED_STATUS,
                DELEGATION_INIT_WITHDRAWAL_DELAY_BLOCKS,
                // NOTE: passing in empty arrays for these two for now while figuring out how to deploy strategies
                // TODO: change these once strategy deployments are handled
                strategies,
                withdrawalDelayBlocks
            )
        );
        eigenLayerProxyAdmin.upgradeAndCall(
            ITransparentUpgradeableProxy(payable(address(strategyManager))),
            address(strategyManagerImplementation),
            abi.encodeWithSelector(
                StrategyManager.initialize.selector,
                admin,
                admin,
                eigenLayerPauserReg,
                STRATEGY_MANAGER_INIT_PAUSED_STATUS
            )
        );
        eigenLayerProxyAdmin.upgradeAndCall(
            ITransparentUpgradeableProxy(payable(address(slasher))),
            address(slasherImplementation),
            abi.encodeWithSelector(Slasher.initialize.selector, admin, eigenLayerPauserReg, SLASHER_INIT_PAUSED_STATUS)
        );
        eigenLayerProxyAdmin.upgradeAndCall(
            ITransparentUpgradeableProxy(payable(address(eigenPodManager))),
            address(eigenPodManagerImplementation),
            abi.encodeWithSelector(
                EigenPodManager.initialize.selector,
                // EIGENPOD_MANAGER_MAX_PODS, //this was deprecated to not be included in latest version of EigenPodManager
                // @audit this is setting the oracle address to 0 initially
                IBeaconChainOracle(address(0)),
                admin,
                eigenLayerPauserReg,
                EIGENPOD_MANAGER_INIT_PAUSED_STATUS
            )
        );
        eigenLayerProxyAdmin.upgradeAndCall(
            ITransparentUpgradeableProxy(payable(address(delayedWithdrawalRouter))),
            address(delayedWithdrawalRouterImplementation),
            abi.encodeWithSelector(
                DelayedWithdrawalRouter.initialize.selector,
                admin,
                eigenLayerPauserReg,
                DELAYED_WITHDRAWAL_ROUTER_INIT_PAUSED_STATUS,
                DELAYED_WITHDRAWAL_ROUTER_INIT_WITHDRAWAL_DELAY_BLOCKS
            )
        );

        baseStrategyImplementation = new StrategyBaseTVLLimits(strategyManager);
        // creates upgradeable proxies of strategies that each point to the implementation and initialize them
        for (uint256 i = 0; i < _tokenAddresses.length; ++i) {
            deployedStrategyArray.push(
                StrategyBaseTVLLimits(
                    address(
                        new TransparentUpgradeableProxy(
                            address(baseStrategyImplementation),
                            address(eigenLayerProxyAdmin),
                            abi.encodeWithSelector(
                                StrategyBaseTVLLimits.initialize.selector,
                                type(uint256).max,
                                type(uint256).max,
                                IERC20(_tokenAddresses[i]),
                                eigenLayerPauserReg
                            )
                        )
                    )
                )
            );
        }

        // set the strategy whitelist in strategyManager
        bool[] memory thirdPartyTransfers = new bool[](deployedStrategyArray.length); // default to allowing third party transfers
        IStrategy[] memory simpleStrategyArray = new IStrategy[](deployedStrategyArray.length);

        // create an array of strategies using their interfaces to be able to pass into strategyManager whitelisting
        for (uint256 i = 0; i < deployedStrategyArray.length; ++i) {
            simpleStrategyArray[i] = IStrategy(address(deployedStrategyArray[i]));
        }
        strategyManager.addStrategiesToDepositWhitelist(simpleStrategyArray, thirdPartyTransfers);

        // CHECK CORRECTNESS OF DEPLOYMENT
        _verifyContractsPointAtOneAnother(
            delegationImplementation,
            strategyManagerImplementation,
            slasherImplementation,
            eigenPodManagerImplementation,
            delayedWithdrawalRouterImplementation
        );
        _verifyContractsPointAtOneAnother(
            delegation,
            strategyManager,
            slasher,
            eigenPodManager,
            delayedWithdrawalRouter
        );
        _verifyImplementationsSetCorrectly();
        _verifyInitialOwners();
        _checkPauserInitializations();
        _verifyInitializationParams();
    }

    function deployEigenLayerForked(address[] memory _strategies) internal {
        _setAddresses();
        // what actually needs to be deployed here if EigenLayer is already deployed on mainnet?
        // TODO: need to use the admin address to grant permissions to admin account here or mock the deployed admin

        // TODO: need to read deployed contract state to figure out what account is proxy admin
        // eigenLayerProxyAdmin = ProxyAdmin(eigenLayerProxyAdminAddress);

        eigenLayerPauserReg = PauserRegistry(eigenLayerPauserRegAddress);

        delegation = DelegationManager(delegationAddress);
        strategyManager = StrategyManager(strategyManagerAddress);
        slasher = Slasher(slasherAddress);
        eigenPodManager = EigenPodManager(eigenPodManagerAddress);
        delayedWithdrawalRouter = DelayedWithdrawalRouter(delayedWithdrawalRouterAddress);

        // don't need to mock the ETHPOS deposit contract because deployed EigenPod points to it
        eigenPodBeacon = UpgradeableBeacon(eigenPodBeaconAddress);

        deployedForkStrategyArray = new StrategyBase[](_strategies.length);
        console2.log("strategies length: ", _strategies.length);
        // get the deployed strategies used in Renzo to use here
        deployedForkStrategyArray.push(StrategyBase(_strategies[0]));
        deployedForkStrategyArray.push(StrategyBase(_strategies[1]));

        // set the strategy whitelist in strategyManager
        bool[] memory thirdPartyTransfers = new bool[](_strategies.length); // default to allowing third party transfers
        IStrategy[] memory simpleStrategyArray = new IStrategy[](_strategies.length);

        // create an array of strategies using their interfaces to be able to pass into strategyManager whitelisting
        // NOTE: may cause issue that leads to revert when testing
        for (uint256 i = 0; i < _strategies.length; ++i) {
            simpleStrategyArray[i] = IStrategy(address(deployedForkStrategyArray[i]));
        }
        strategyManager.addStrategiesToDepositWhitelist(simpleStrategyArray, thirdPartyTransfers);
    }

    // @audit this function sets contract addresses with those deployed on mainnet
    function _setAddresses() internal {
        // eigenLayerProxyAdminAddress = stdJson.readAddress(config, ".addresses.eigenLayerProxyAdmin");
        eigenLayerPauserRegAddress = address(0x0c431C66F4dE941d089625E5B423D00707977060);
        // NOTE: the following addresses are the proxies, not implementation
        delegationAddress = address(0x39053D51B77DC0d36036Fc1fCc8Cb819df8Ef37A);
        strategyManagerAddress = address(0x858646372CC42E1A627fcE94aa7A7033e7CF075A);
        slasherAddress = address(0xD92145c07f8Ed1D392c1B88017934E301CC1c3Cd);
        eigenPodManagerAddress = address(0x91E677b07F7AF907ec9a428aafA9fc14a0d3A338);
        delayedWithdrawalRouterAddress = address(0x7Fe7E9CC0F274d2435AD5d56D5fa73E47F6A23D8);
        beaconChainOracleAddress = address(0x343907185b71aDF0eBa9567538314396aa985442);
        eigenPodBeaconAddress = address(0x5a2a4F2F3C18f09179B6703e63D9eDD165909073);
        cbETHStrategyAddress = address(0x54945180dB7943c0ed0FEE7EdaB2Bd24620256bc);
        stETHStrategyAddress = address(0x93c4b944D05dfe6df7645A86cd2206016c51564D);

        operationsMultisig = address(0xBE1685C81aA44FF9FB319dD389addd9374383e90);
        executorMultisig = address(0x369e6F597e22EaB55fFb173C6d9cD234BD699111);
    }

    function _verifyContractsPointAtOneAnother(
        DelegationManager delegationContract,
        StrategyManager strategyManagerContract,
        Slasher slasherContract,
        EigenPodManager eigenPodManagerContract,
        DelayedWithdrawalRouter delayedWithdrawalRouterContract
    ) internal view {
        require(delegationContract.slasher() == slasher, "delegation: slasher address not set correctly");
        require(
            delegationContract.strategyManager() == strategyManager,
            "delegation: strategyManager address not set correctly"
        );

        require(strategyManagerContract.slasher() == slasher, "strategyManager: slasher address not set correctly");
        require(
            strategyManagerContract.delegation() == delegation,
            "strategyManager: delegation address not set correctly"
        );
        require(
            strategyManagerContract.eigenPodManager() == eigenPodManager,
            "strategyManager: eigenPodManager address not set correctly"
        );

        // NOTE: slasher implementation not completed so leaving these out
        // require(slasherContract.strategyManager() == strategyManager, "slasher: strategyManager not set correctly");
        // require(slasherContract.delegation() == delegation, "slasher: delegation not set correctly");

        require(
            eigenPodManagerContract.ethPOS() == ethPOSDepositMock,
            " eigenPodManager: ethPOSDeposit contract address not set correctly"
        );
        require(
            eigenPodManagerContract.eigenPodBeacon() == eigenPodBeacon,
            "eigenPodManager: eigenPodBeacon contract address not set correctly"
        );
        require(
            eigenPodManagerContract.strategyManager() == strategyManager,
            "eigenPodManager: strategyManager contract address not set correctly"
        );
        require(
            eigenPodManagerContract.slasher() == slasher,
            "eigenPodManager: slasher contract address not set correctly"
        );

        require(
            delayedWithdrawalRouterContract.eigenPodManager() == eigenPodManager,
            "delayedWithdrawalRouterContract: eigenPodManager address not set correctly"
        );
    }

    function _verifyImplementationsSetCorrectly() internal view {
        require(
            eigenLayerProxyAdmin.getProxyImplementation(ITransparentUpgradeableProxy(payable(address(delegation)))) ==
                address(delegationImplementation),
            "delegation: implementation set incorrectly"
        );
        require(
            eigenLayerProxyAdmin.getProxyImplementation(
                ITransparentUpgradeableProxy(payable(address(strategyManager)))
            ) == address(strategyManagerImplementation),
            "strategyManager: implementation set incorrectly"
        );
        require(
            eigenLayerProxyAdmin.getProxyImplementation(ITransparentUpgradeableProxy(payable(address(slasher)))) ==
                address(slasherImplementation),
            "slasher: implementation set incorrectly"
        );
        require(
            eigenLayerProxyAdmin.getProxyImplementation(
                ITransparentUpgradeableProxy(payable(address(eigenPodManager)))
            ) == address(eigenPodManagerImplementation),
            "eigenPodManager: implementation set incorrectly"
        );
        require(
            eigenLayerProxyAdmin.getProxyImplementation(
                ITransparentUpgradeableProxy(payable(address(delayedWithdrawalRouter)))
            ) == address(delayedWithdrawalRouterImplementation),
            "delayedWithdrawalRouter: implementation set incorrectly"
        );

        for (uint256 i = 0; i < deployedStrategyArray.length; ++i) {
            require(
                eigenLayerProxyAdmin.getProxyImplementation(
                    ITransparentUpgradeableProxy(payable(address(deployedStrategyArray[i])))
                ) == address(baseStrategyImplementation),
                "strategy: implementation set incorrectly"
            );
        }

        require(
            eigenPodBeacon.implementation() == address(eigenPodImplementation),
            "eigenPodBeacon: implementation set incorrectly"
        );
    }

    function _verifyInitialOwners() internal view {
        require(strategyManager.owner() == admin, "strategyManager: owner not set correctly");
        require(delegation.owner() == admin, "delegation: owner not set correctly");
        // NOTE: slasher implementation not complete, leaving out
        // require(slasher.owner() == admin, "slasher: owner not set correctly");
        require(eigenPodManager.owner() == admin, "delegation: owner not set correctly");

        require(eigenLayerProxyAdmin.owner() == admin, "eigenLayerProxyAdmin: owner not set correctly");
        require(eigenPodBeacon.owner() == admin, "eigenPodBeacon: owner not set correctly");
        require(delayedWithdrawalRouter.owner() == admin, "delayedWithdrawalRouter: owner not set correctly");
    }

    function _checkPauserInitializations() internal view {
        require(delegation.pauserRegistry() == eigenLayerPauserReg, "delegation: pauser registry not set correctly");
        require(
            strategyManager.pauserRegistry() == eigenLayerPauserReg,
            "strategyManager: pauser registry not set correctly"
        );
        // NOTE: slasher development not finished
        // require(slasher.pauserRegistry() == eigenLayerPauserReg, "slasher: pauser registry not set correctly");
        require(
            eigenPodManager.pauserRegistry() == eigenLayerPauserReg,
            "eigenPodManager: pauser registry not set correctly"
        );
        require(
            delayedWithdrawalRouter.pauserRegistry() == eigenLayerPauserReg,
            "delayedWithdrawalRouter: pauser registry not set correctly"
        );

        require(eigenLayerPauserReg.isPauser(admin), "pauserRegistry: operationsMultisig is not pauser");
        require(eigenLayerPauserReg.isPauser(admin), "pauserRegistry: executorMultisig is not pauser");
        require(eigenLayerPauserReg.isPauser(admin), "pauserRegistry: pauserMultisig is not pauser");
        require(eigenLayerPauserReg.unpauser() == admin, "pauserRegistry: unpauser not set correctly");

        for (uint256 i = 0; i < deployedStrategyArray.length; ++i) {
            require(
                deployedStrategyArray[i].pauserRegistry() == eigenLayerPauserReg,
                "StrategyBaseTVLLimits: pauser registry not set correctly"
            );
            require(
                deployedStrategyArray[i].paused() == 0,
                "StrategyBaseTVLLimits: init paused status set incorrectly"
            );
        }

        // // pause *nothing*
        // uint256 STRATEGY_MANAGER_INIT_PAUSED_STATUS = 0;
        // // pause *everything*
        // uint256 SLASHER_INIT_PAUSED_STATUS = type(uint256).max;
        // // pause *everything*
        // uint256 DELEGATION_INIT_PAUSED_STATUS = type(uint256).max;
        // // pause *all of the proof-related functionality* (everything that can be paused other than creation of EigenPods)
        // uint256 EIGENPOD_MANAGER_INIT_PAUSED_STATUS = (2**1) + (2**2) + (2**3) + (2**4); /* = 30 */
        // // pause *nothing*
        // uint256 DELAYED_WITHDRAWAL_ROUTER_INIT_PAUSED_STATUS = 0;
        require(strategyManager.paused() == 0, "strategyManager: init paused status set incorrectly");
        require(slasher.paused() == 0, "slasher: init paused status set incorrectly");
        require(delegation.paused() == 0, "delegation: init paused status set incorrectly");
        require(eigenPodManager.paused() == 0, "eigenPodManager: init paused status set incorrectly");
        require(delayedWithdrawalRouter.paused() == 0, "delayedWithdrawalRouter: init paused status set incorrectly");
    }

    function _verifyInitializationParams() internal {
        // // one week in blocks -- 50400
        // uint32 STRATEGY_MANAGER_INIT_WITHDRAWAL_DELAY_BLOCKS = 7 days / 12 seconds;
        // uint32 DELAYED_WITHDRAWAL_ROUTER_INIT_WITHDRAWAL_DELAY_BLOCKS = 7 days / 12 seconds;
        // require(strategyManager.withdrawalDelayBlocks() == 7 days / 12 seconds,
        //     "strategyManager: withdrawalDelayBlocks initialized incorrectly");
        // require(delayedWithdrawalRouter.withdrawalDelayBlocks() == 7 days / 12 seconds,
        //     "delayedWithdrawalRouter: withdrawalDelayBlocks initialized incorrectly");
        // uint256 REQUIRED_BALANCE_WEI = 32 ether;

        require(
            strategyManager.strategyWhitelister() == admin,
            "strategyManager: strategyWhitelister address not set correctly"
        );

        require(
            eigenPodManager.beaconChainOracle() == IBeaconChainOracle(address(0)),
            "eigenPodManager: eigenPodBeacon contract address not set correctly"
        );

        require(
            delayedWithdrawalRouter.eigenPodManager() == eigenPodManager,
            "delayedWithdrawalRouter: eigenPodManager set incorrectly"
        );

        require(
            baseStrategyImplementation.strategyManager() == strategyManager,
            "baseStrategyImplementation: strategyManager set incorrectly"
        );

        require(
            eigenPodImplementation.ethPOS() == ethPOSDepositMock,
            "eigenPodImplementation: ethPOSDeposit contract address not set correctly"
        );
        require(
            eigenPodImplementation.eigenPodManager() == eigenPodManager,
            " eigenPodImplementation: eigenPodManager contract address not set correctly"
        );
        require(
            eigenPodImplementation.delayedWithdrawalRouter() == delayedWithdrawalRouter,
            " eigenPodImplementation: delayedWithdrawalRouter contract address not set correctly"
        );

        // @audit skipping this for now, assume strategy deployments to be correct
        // for (uint i = 0; i < tokenAddresses.length; i++) {
        //     uint256 maxPerDeposit = type(uint256).max;
        //     uint256 maxDeposits = type(uint256).max;
        //     (uint256 setMaxPerDeposit, uint256 setMaxDeposits) = tokenAddresses[i].getTVLLimits();
        //     require(setMaxPerDeposit == maxPerDeposit, "setMaxPerDeposit not set correctly");
        //     require(setMaxDeposits == maxDeposits, "setMaxDeposits not set correctly");
        // }
    }
}
