// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "../access/Governable.sol";
import "../peripherals/interfaces/ITimelock.sol";

contract RewardManager is Governable {

    bool public isInitialized;

    ITimelock public timelock;
    address public rewardRouter;

    address public dlpManager;

    address public stakedDfexTracker;
    address public bonusDfexTracker;
    address public feeDfexTracker;

    address public feeDlpTracker;
    address public stakedDlpTracker;

    address public stakedDfexDistributor;
    address public stakedDlpDistributor;

    address public esDfex;
    address public bnDfex;

    address public dfexVester;
    address public dlpVester;

    function initialize(
        ITimelock _timelock,
        address _rewardRouter,
        address _dlpManager,
        address _stakedDfexTracker,
        address _bonusDfexTracker,
        address _feeDfexTracker,
        address _feeDlpTracker,
        address _stakedDlpTracker,
        address _stakedDfexDistributor,
        address _stakedDlpDistributor,
        address _esDfex,
        address _bnDfex,
        address _dfexVester,
        address _dlpVester
    ) external onlyGov {
        require(!isInitialized, "RewardManager: already initialized");
        isInitialized = true;

        timelock = _timelock;
        rewardRouter = _rewardRouter;

        dlpManager = _dlpManager;

        stakedDfexTracker = _stakedDfexTracker;
        bonusDfexTracker = _bonusDfexTracker;
        feeDfexTracker = _feeDfexTracker;

        feeDlpTracker = _feeDlpTracker;
        stakedDlpTracker = _stakedDlpTracker;

        stakedDfexDistributor = _stakedDfexDistributor;
        stakedDlpDistributor = _stakedDlpDistributor;

        esDfex = _esDfex;
        bnDfex = _bnDfex;

        dfexVester = _dfexVester;
        dlpVester = _dlpVester;
    }

    function updateEsDfexHandlers() external onlyGov {
        timelock.managedSetHandler(esDfex, rewardRouter, true);

        timelock.managedSetHandler(esDfex, stakedDfexDistributor, true);
        timelock.managedSetHandler(esDfex, stakedDlpDistributor, true);

        timelock.managedSetHandler(esDfex, stakedDfexTracker, true);
        timelock.managedSetHandler(esDfex, stakedDlpTracker, true);

        timelock.managedSetHandler(esDfex, dfexVester, true);
        timelock.managedSetHandler(esDfex, dlpVester, true);
    }

    function enableRewardRouter() external onlyGov {
        timelock.managedSetHandler(dlpManager, rewardRouter, true);

        timelock.managedSetHandler(stakedDfexTracker, rewardRouter, true);
        timelock.managedSetHandler(bonusDfexTracker, rewardRouter, true);
        timelock.managedSetHandler(feeDfexTracker, rewardRouter, true);

        timelock.managedSetHandler(feeDlpTracker, rewardRouter, true);
        timelock.managedSetHandler(stakedDlpTracker, rewardRouter, true);

        timelock.managedSetHandler(esDfex, rewardRouter, true);

        timelock.managedSetMinter(bnDfex, rewardRouter, true);

        timelock.managedSetMinter(esDfex, dfexVester, true);
        timelock.managedSetMinter(esDfex, dlpVester, true);

        timelock.managedSetHandler(dfexVester, rewardRouter, true);
        timelock.managedSetHandler(dlpVester, rewardRouter, true);

        timelock.managedSetHandler(feeDfexTracker, dfexVester, true);
        timelock.managedSetHandler(stakedDlpTracker, dlpVester, true);
    }
}
