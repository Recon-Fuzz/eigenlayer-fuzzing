
// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.0;

import {BaseSetup} from "@chimera/BaseSetup.sol";

import "src/test/WithdrawalMigration.t.sol";
import "src/test/unit/StrategyBaseTVLLimitsUnit.sol";
import "src/contracts/permissions/Pausable.sol";
import "src/test/mocks/DelegationManagerMock.sol";
import "src/contracts/interfaces/IStrategy.sol";
import "src/contracts/core/StrategyManagerStorage.sol";
import "src/contracts/strategies/StrategyBase.sol";
import "src/contracts/core/DelegationManager.sol";
import "src/contracts/pods/DelayedWithdrawalRouter.sol";
import "src/contracts/interfaces/IEigenPodManager.sol";
import "src/test/EigenLayerDeployer.t.sol";
import "src/contracts/interfaces/IAVSDirectory.sol";
import "src/test/utils/Operators.sol";
import "src/test/integration/tests/Delegate_Deposit_Queue_Complete.t.sol";
import "src/test/mocks/ERC20Mock.sol";
import "src/test/integration/IntegrationDeployer.t.sol";
import "src/test/integration/tests/Deposit_Delegate_Queue_Complete.t.sol";
import "src/test/integration/IntegrationBase.t.sol";
import "src/contracts/core/DelegationManagerStorage.sol";
import "src/contracts/interfaces/IWhitelister.sol";
import "src/contracts/interfaces/ISocketUpdater.sol";
import "src/contracts/interfaces/ISlasher.sol";
import "src/test/mocks/DelayedWithdrawalRouterMock.sol";
import "src/contracts/interfaces/IStrategyManager.sol";
import "src/test/events/IEigenPodEvents.sol";
import "src/test/utils/Owners.sol";
import "src/test/utils/ProofParsing.sol";
import "src/test/events/IStrategyManagerEvents.sol";
import "src/test/mocks/Reenterer.sol";
import "src/test/mocks/StrategyManagerMock.sol";
import "src/test/harnesses/PausableHarness.sol";
import "src/test/integration/tests/Deposit_Queue_Complete.t.sol";
import "src/contracts/interfaces/IDelayedWithdrawalRouter.sol";
import "src/test/mocks/SlasherMock.sol";
import "src/test/mocks/EigenPodMock.sol";
import "src/test/DelegationFaucet.t.sol";
import "src/test/unit/EigenPodManagerUnit.t.sol";
import "src/test/integration/IntegrationChecks.t.sol";
import "src/test/Withdrawals.t.sol";
import "src/test/integration/TimeMachine.t.sol";
import "src/test/Strategy.t.sol";
import "src/test/EigenLayerTestHelper.t.sol";
import "src/test/harnesses/EigenPodManagerWrapper.sol";
import "src/test/mocks/IBeaconChainOracleMock.sol";
import "src/contracts/pods/EigenPodManagerStorage.sol";
import "src/test/unit/EigenPod-PodManagerUnit.t.sol";
import "src/test/integration/tests/Deposit_Delegate_UpdateBalance.t.sol";
import "src/test/DepositWithdraw.t.sol";
import "src/test/events/IDelegationManagerEvents.sol";
import "src/test/integration/tests/Deposit_Delegate_Undelegate_Complete.t.sol";
import "src/test/mocks/ERC20_SetTransferReverting_Mock.sol";
import "src/contracts/core/AVSDirectory.sol";
import "src/contracts/strategies/StrategyBaseTVLLimits.sol";
import "src/contracts/core/StrategyManager.sol";
import "src/test/unit/PausableUnit.t.sol";
import "src/test/unit/StrategyManagerUnit.t.sol";
import "src/test/integration/tests/Deposit_Register_QueueWithdrawal_Complete.t.sol";
import "src/test/unit/PauserRegistryUnit.t.sol";
import "src/test/unit/EigenPodUnit.t.sol";
import "src/contracts/interfaces/IPausable.sol";
import "src/test/mocks/Reverter.sol";
import "src/test/integration/mocks/BeaconChainMock.t.sol";
import "src/test/Delegation.t.sol";
import "src/contracts/interfaces/IBeaconChainOracle.sol";
import "src/contracts/interfaces/IEigenPod.sol";
import "src/contracts/interfaces/IDelegationFaucet.sol";
import "src/contracts/core/AVSDirectoryStorage.sol";
import "src/test/events/IEigenPodManagerEvents.sol";
import "src/test/integration/User.t.sol";
import "src/contracts/interfaces/IPauserRegistry.sol";
import "src/test/utils/Utils.sol";
import "src/test/utils/EigenLayerUnitTestBase.sol";
import "src/test/EigenPod.t.sol";
import "src/test/unit/DelegationUnit.t.sol";
import "src/contracts/permissions/PauserRegistry.sol";
import "src/contracts/interfaces/IETHPOSDeposit.sol";
import "src/test/harnesses/EigenPodHarness.sol";
import "src/test/mocks/ERC20_OneWeiFeeOnTransfer.sol";
import "src/test/Pausable.t.sol";
import "src/test/mocks/OwnableMock.sol";
import "src/test/events/IAVSDirectoryEvents.sol";
import "src/test/integration/tests/Deposit_Delegate_Redelegate_Complete.t.sol";
import "src/contracts/core/Slasher.sol";
import "src/test/mocks/EigenPodManagerMock.sol";
import "src/contracts/utils/UpgradeableSignatureCheckingUtils.sol";
import "src/test/utils/EigenLayerUnitTestSetup.sol";
import "src/test/unit/AVSDirectoryUnit.t.sol";
import "src/test/mocks/LiquidStakingToken.sol";
import "src/contracts/pods/EigenPodManager.sol";
import "src/contracts/interfaces/IDelegationManager.sol";
import "src/test/mocks/ETHDepositMock.sol";
import "src/contracts/pods/EigenPod.sol";
import "src/test/unit/StrategyBaseUnit.t.sol";
import "src/test/unit/DelayedWithdrawalRouterUnit.t.sol";

abstract contract Setup is BaseSetup {

    EigenPodManager eigenPodManager;
    EigenPod eigenPod;
    DelayedWithdrawalRouter delayedWithdrawalRouter;

    function setup() internal virtual override {
      eigenPodManager = new EigenPodManager(); // TODO: Add parameters here
      eigenPod = new EigenPod(); // TODO: Add parameters here
      delayedWithdrawalRouter = new DelayedWithdrawalRouter(); // TODO: Add parameters here
    }
}
