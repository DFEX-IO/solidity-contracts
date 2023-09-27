// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "../libraries/math/SafeMath.sol";
import "../libraries/token/IERC20.sol";
import "../libraries/token/SafeERC20.sol";
import "../libraries/utils/ReentrancyGuard.sol";
import "../libraries/utils/Address.sol";

import "./interfaces/IRewardTracker.sol";
import "./interfaces/IVester.sol";
import "../tokens/interfaces/IMintable.sol";
import "../tokens/interfaces/IWETH.sol";
import "../core/interfaces/IDlpManager.sol";
import "../access/Governable.sol";

contract RewardRouterV2 is ReentrancyGuard, Governable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    using Address for address payable;

    bool public isInitialized;

    address public weth;

    address public dfex;
    address public esDfex;
    address public bnDfex;

    address public dlp; // DFEX Liquidity Provider token

    address public stakedDfexTracker;
    address public bonusDfexTracker;
    address public feeDfexTracker;

    address public stakedDlpTracker;
    address public feeDlpTracker;

    address public dlpManager;

    address public dfexVester;
    address public dlpVester;

    mapping (address => address) public pendingReceivers;

    event StakeDfex(address account, address token, uint256 amount);
    event UnstakeDfex(address account, address token, uint256 amount);

    event StakeDlp(address account, uint256 amount);
    event UnstakeDlp(address account, uint256 amount);

    receive() external payable {
        require(msg.sender == weth, "Router: invalid sender");
    }

    function initialize(
        address _weth,
        address _dfex,
        address _esDfex,
        address _bnDfex,
        address _dlp,
        address _stakedDfexTracker,
        address _bonusDfexTracker,
        address _feeDfexTracker,
        address _feeDlpTracker,
        address _stakedDlpTracker,
        address _dlpManager,
        address _dfexVester,
        address _dlpVester
    ) external onlyGov {
        require(!isInitialized, "RewardRouter: already initialized");
        isInitialized = true;

        weth = _weth;

        dfex = _dfex;
        esDfex = _esDfex;
        bnDfex = _bnDfex;

        dlp = _dlp;

        stakedDfexTracker = _stakedDfexTracker;
        bonusDfexTracker = _bonusDfexTracker;
        feeDfexTracker = _feeDfexTracker;

        feeDlpTracker = _feeDlpTracker;
        stakedDlpTracker = _stakedDlpTracker;

        dlpManager = _dlpManager;

        dfexVester = _dfexVester;
        dlpVester = _dlpVester;
    }

    // to help users who accidentally send their tokens to this contract
    function withdrawToken(address _token, address _account, uint256 _amount) external onlyGov {
        IERC20(_token).safeTransfer(_account, _amount);
    }

    function batchStakeDfexForAccount(address[] memory _accounts, uint256[] memory _amounts) external nonReentrant onlyGov {
        address _dfex = dfex;
        for (uint256 i = 0; i < _accounts.length; i++) {
            _stakeDfex(msg.sender, _accounts[i], _dfex, _amounts[i]);
        }
    }

    function stakeDfexForAccount(address _account, uint256 _amount) external nonReentrant onlyGov {
        _stakeDfex(msg.sender, _account, dfex, _amount);
    }

    function stakeDfex(uint256 _amount) external nonReentrant {
        _stakeDfex(msg.sender, msg.sender, dfex, _amount);
    }

    function stakeEsDfex(uint256 _amount) external nonReentrant {
        _stakeDfex(msg.sender, msg.sender, esDfex, _amount);
    }

    function unstakeDfex(uint256 _amount) external nonReentrant {
        _unstakeDfex(msg.sender, dfex, _amount, true);
    }

    function unstakeEsDfex(uint256 _amount) external nonReentrant {
        _unstakeDfex(msg.sender, esDfex, _amount, true);
    }

    function mintAndStakeDlp(address _token, uint256 _amount, uint256 _minUsdd, uint256 _minDlp) external nonReentrant returns (uint256) {
        require(_amount > 0, "RewardRouter: invalid _amount");

        address account = msg.sender;
        uint256 dlpAmount = IDlpManager(dlpManager).addLiquidityForAccount(account, account, _token, _amount, _minUsdd, _minDlp);
        IRewardTracker(feeDlpTracker).stakeForAccount(account, account, dlp, dlpAmount);
        IRewardTracker(stakedDlpTracker).stakeForAccount(account, account, feeDlpTracker, dlpAmount);

        emit StakeDlp(account, dlpAmount);

        return dlpAmount;
    }

    function mintAndStakeDlpETH(uint256 _minUsdd, uint256 _minDlp) external payable nonReentrant returns (uint256) {
        require(msg.value > 0, "RewardRouter: invalid msg.value");

        IWETH(weth).deposit{value: msg.value}();
        IERC20(weth).approve(dlpManager, msg.value);

        address account = msg.sender;
        uint256 dlpAmount = IDlpManager(dlpManager).addLiquidityForAccount(address(this), account, weth, msg.value, _minUsdd, _minDlp);

        IRewardTracker(feeDlpTracker).stakeForAccount(account, account, dlp, dlpAmount);
        IRewardTracker(stakedDlpTracker).stakeForAccount(account, account, feeDlpTracker, dlpAmount);

        emit StakeDlp(account, dlpAmount);

        return dlpAmount;
    }

    function unstakeAndRedeemDlp(address _tokenOut, uint256 _dlpAmount, uint256 _minOut, address _receiver) external nonReentrant returns (uint256) {
        require(_dlpAmount > 0, "RewardRouter: invalid _dlpAmount");

        address account = msg.sender;
        IRewardTracker(stakedDlpTracker).unstakeForAccount(account, feeDlpTracker, _dlpAmount, account);
        IRewardTracker(feeDlpTracker).unstakeForAccount(account, dlp, _dlpAmount, account);
        uint256 amountOut = IDlpManager(dlpManager).removeLiquidityForAccount(account, _tokenOut, _dlpAmount, _minOut, _receiver);

        emit UnstakeDlp(account, _dlpAmount);

        return amountOut;
    }

    function unstakeAndRedeemDlpETH(uint256 _dlpAmount, uint256 _minOut, address payable _receiver) external nonReentrant returns (uint256) {
        require(_dlpAmount > 0, "RewardRouter: invalid _dlpAmount");

        address account = msg.sender;
        IRewardTracker(stakedDlpTracker).unstakeForAccount(account, feeDlpTracker, _dlpAmount, account);
        IRewardTracker(feeDlpTracker).unstakeForAccount(account, dlp, _dlpAmount, account);
        uint256 amountOut = IDlpManager(dlpManager).removeLiquidityForAccount(account, weth, _dlpAmount, _minOut, address(this));

        IWETH(weth).withdraw(amountOut);

        _receiver.sendValue(amountOut);

        emit UnstakeDlp(account, _dlpAmount);

        return amountOut;
    }

    function claim() external nonReentrant {
        address account = msg.sender;

        IRewardTracker(feeDfexTracker).claimForAccount(account, account);
        IRewardTracker(feeDlpTracker).claimForAccount(account, account);

        IRewardTracker(stakedDfexTracker).claimForAccount(account, account);
        IRewardTracker(stakedDlpTracker).claimForAccount(account, account);
    }

    function claimEsDfex() external nonReentrant {
        address account = msg.sender;

        IRewardTracker(stakedDfexTracker).claimForAccount(account, account);
        IRewardTracker(stakedDlpTracker).claimForAccount(account, account);
    }

    function claimFees() external nonReentrant {
        address account = msg.sender;

        IRewardTracker(feeDfexTracker).claimForAccount(account, account);
        IRewardTracker(feeDlpTracker).claimForAccount(account, account);
    }

    function compound() external nonReentrant {
        _compound(msg.sender);
    }

    function compoundForAccount(address _account) external nonReentrant onlyGov {
        _compound(_account);
    }

    function handleRewards(
        bool _shouldClaimDfex,
        bool _shouldStakeDfex,
        bool _shouldClaimEsDfex,
        bool _shouldStakeEsDfex,
        bool _shouldStakeMultiplierPoints,
        bool _shouldClaimWeth,
        bool _shouldConvertWethToEth
    ) external nonReentrant {
        address account = msg.sender;

        uint256 dfexAmount = 0;
        if (_shouldClaimDfex) {
            uint256 dfexAmount0 = IVester(dfexVester).claimForAccount(account, account);
            uint256 dfexAmount1 = IVester(dlpVester).claimForAccount(account, account);
            dfexAmount = dfexAmount0.add(dfexAmount1);
        }

        if (_shouldStakeDfex && dfexAmount > 0) {
            _stakeDfex(account, account, dfex, dfexAmount);
        }

        uint256 esDfexAmount = 0;
        if (_shouldClaimEsDfex) {
            uint256 esDfexAmount0 = IRewardTracker(stakedDfexTracker).claimForAccount(account, account);
            uint256 esDfexAmount1 = IRewardTracker(stakedDlpTracker).claimForAccount(account, account);
            esDfexAmount = esDfexAmount0.add(esDfexAmount1);
        }

        if (_shouldStakeEsDfex && esDfexAmount > 0) {
            _stakeDfex(account, account, esDfex, esDfexAmount);
        }

        if (_shouldStakeMultiplierPoints) {
            uint256 bnDfexAmount = IRewardTracker(bonusDfexTracker).claimForAccount(account, account);
            if (bnDfexAmount > 0) {
                IRewardTracker(feeDfexTracker).stakeForAccount(account, account, bnDfex, bnDfexAmount);
            }
        }

        if (_shouldClaimWeth) {
            if (_shouldConvertWethToEth) {
                uint256 weth0 = IRewardTracker(feeDfexTracker).claimForAccount(account, address(this));
                uint256 weth1 = IRewardTracker(feeDlpTracker).claimForAccount(account, address(this));

                uint256 wethAmount = weth0.add(weth1);
                IWETH(weth).withdraw(wethAmount);

                payable(account).sendValue(wethAmount);
            } else {
                IRewardTracker(feeDfexTracker).claimForAccount(account, account);
                IRewardTracker(feeDlpTracker).claimForAccount(account, account);
            }
        }
    }

    function batchCompoundForAccounts(address[] memory _accounts) external nonReentrant onlyGov {
        for (uint256 i = 0; i < _accounts.length; i++) {
            _compound(_accounts[i]);
        }
    }

    function signalTransfer(address _receiver) external nonReentrant {
        require(IERC20(dfexVester).balanceOf(msg.sender) == 0, "RewardRouter: sender has vested tokens");
        require(IERC20(dlpVester).balanceOf(msg.sender) == 0, "RewardRouter: sender has vested tokens");

        _validateReceiver(_receiver);
        pendingReceivers[msg.sender] = _receiver;
    }

    function acceptTransfer(address _sender) external nonReentrant {
        require(IERC20(dfexVester).balanceOf(_sender) == 0, "RewardRouter: sender has vested tokens");
        require(IERC20(dlpVester).balanceOf(_sender) == 0, "RewardRouter: sender has vested tokens");

        address receiver = msg.sender;
        require(pendingReceivers[_sender] == receiver, "RewardRouter: transfer not signalled");
        delete pendingReceivers[_sender];

        _validateReceiver(receiver);
        _compound(_sender);

        uint256 stakedDfex = IRewardTracker(stakedDfexTracker).depositBalances(_sender, dfex);
        if (stakedDfex > 0) {
            _unstakeDfex(_sender, dfex, stakedDfex, false);
            _stakeDfex(_sender, receiver, dfex, stakedDfex);
        }

        uint256 stakedEsDfex = IRewardTracker(stakedDfexTracker).depositBalances(_sender, esDfex);
        if (stakedEsDfex > 0) {
            _unstakeDfex(_sender, esDfex, stakedEsDfex, false);
            _stakeDfex(_sender, receiver, esDfex, stakedEsDfex);
        }

        uint256 stakedBnDfex = IRewardTracker(feeDfexTracker).depositBalances(_sender, bnDfex);
        if (stakedBnDfex > 0) {
            IRewardTracker(feeDfexTracker).unstakeForAccount(_sender, bnDfex, stakedBnDfex, _sender);
            IRewardTracker(feeDfexTracker).stakeForAccount(_sender, receiver, bnDfex, stakedBnDfex);
        }

        uint256 esDfexBalance = IERC20(esDfex).balanceOf(_sender);
        if (esDfexBalance > 0) {
            IERC20(esDfex).transferFrom(_sender, receiver, esDfexBalance);
        }

        uint256 dlpAmount = IRewardTracker(feeDlpTracker).depositBalances(_sender, dlp);
        if (dlpAmount > 0) {
            IRewardTracker(stakedDlpTracker).unstakeForAccount(_sender, feeDlpTracker, dlpAmount, _sender);
            IRewardTracker(feeDlpTracker).unstakeForAccount(_sender, dlp, dlpAmount, _sender);

            IRewardTracker(feeDlpTracker).stakeForAccount(_sender, receiver, dlp, dlpAmount);
            IRewardTracker(stakedDlpTracker).stakeForAccount(receiver, receiver, feeDlpTracker, dlpAmount);
        }

        IVester(dfexVester).transferStakeValues(_sender, receiver);
        IVester(dlpVester).transferStakeValues(_sender, receiver);
    }

    function _validateReceiver(address _receiver) private view {
        require(IRewardTracker(stakedDfexTracker).averageStakedAmounts(_receiver) == 0, "RewardRouter: stakedDfexTracker.averageStakedAmounts > 0");
        require(IRewardTracker(stakedDfexTracker).cumulativeRewards(_receiver) == 0, "RewardRouter: stakedDfexTracker.cumulativeRewards > 0");

        require(IRewardTracker(bonusDfexTracker).averageStakedAmounts(_receiver) == 0, "RewardRouter: bonusDfexTracker.averageStakedAmounts > 0");
        require(IRewardTracker(bonusDfexTracker).cumulativeRewards(_receiver) == 0, "RewardRouter: bonusDfexTracker.cumulativeRewards > 0");

        require(IRewardTracker(feeDfexTracker).averageStakedAmounts(_receiver) == 0, "RewardRouter: feeDfexTracker.averageStakedAmounts > 0");
        require(IRewardTracker(feeDfexTracker).cumulativeRewards(_receiver) == 0, "RewardRouter: feeDfexTracker.cumulativeRewards > 0");

        require(IVester(dfexVester).transferredAverageStakedAmounts(_receiver) == 0, "RewardRouter: dfexVester.transferredAverageStakedAmounts > 0");
        require(IVester(dfexVester).transferredCumulativeRewards(_receiver) == 0, "RewardRouter: dfexVester.transferredCumulativeRewards > 0");

        require(IRewardTracker(stakedDlpTracker).averageStakedAmounts(_receiver) == 0, "RewardRouter: stakedDlpTracker.averageStakedAmounts > 0");
        require(IRewardTracker(stakedDlpTracker).cumulativeRewards(_receiver) == 0, "RewardRouter: stakedDlpTracker.cumulativeRewards > 0");

        require(IRewardTracker(feeDlpTracker).averageStakedAmounts(_receiver) == 0, "RewardRouter: feeDlpTracker.averageStakedAmounts > 0");
        require(IRewardTracker(feeDlpTracker).cumulativeRewards(_receiver) == 0, "RewardRouter: feeDlpTracker.cumulativeRewards > 0");

        require(IVester(dlpVester).transferredAverageStakedAmounts(_receiver) == 0, "RewardRouter: dfexVester.transferredAverageStakedAmounts > 0");
        require(IVester(dlpVester).transferredCumulativeRewards(_receiver) == 0, "RewardRouter: dfexVester.transferredCumulativeRewards > 0");

        require(IERC20(dfexVester).balanceOf(_receiver) == 0, "RewardRouter: dfexVester.balance > 0");
        require(IERC20(dlpVester).balanceOf(_receiver) == 0, "RewardRouter: dlpVester.balance > 0");
    }

    function _compound(address _account) private {
        _compoundDfex(_account);
        _compoundDlp(_account);
    }

    function _compoundDfex(address _account) private {
        uint256 esDfexAmount = IRewardTracker(stakedDfexTracker).claimForAccount(_account, _account);
        if (esDfexAmount > 0) {
            _stakeDfex(_account, _account, esDfex, esDfexAmount);
        }

        uint256 bnDfexAmount = IRewardTracker(bonusDfexTracker).claimForAccount(_account, _account);
        if (bnDfexAmount > 0) {
            IRewardTracker(feeDfexTracker).stakeForAccount(_account, _account, bnDfex, bnDfexAmount);
        }
    }

    function _compoundDlp(address _account) private {
        uint256 esDfexAmount = IRewardTracker(stakedDlpTracker).claimForAccount(_account, _account);
        if (esDfexAmount > 0) {
            _stakeDfex(_account, _account, esDfex, esDfexAmount);
        }
    }

    function _stakeDfex(address _fundingAccount, address _account, address _token, uint256 _amount) private {
        require(_amount > 0, "RewardRouter: invalid _amount");

        IRewardTracker(stakedDfexTracker).stakeForAccount(_fundingAccount, _account, _token, _amount);
        IRewardTracker(bonusDfexTracker).stakeForAccount(_account, _account, stakedDfexTracker, _amount);
        IRewardTracker(feeDfexTracker).stakeForAccount(_account, _account, bonusDfexTracker, _amount);

        emit StakeDfex(_account, _token, _amount);
    }

    function _unstakeDfex(address _account, address _token, uint256 _amount, bool _shouldReduceBnDfex) private {
        require(_amount > 0, "RewardRouter: invalid _amount");

        uint256 balance = IRewardTracker(stakedDfexTracker).stakedAmounts(_account);

        IRewardTracker(feeDfexTracker).unstakeForAccount(_account, bonusDfexTracker, _amount, _account);
        IRewardTracker(bonusDfexTracker).unstakeForAccount(_account, stakedDfexTracker, _amount, _account);
        IRewardTracker(stakedDfexTracker).unstakeForAccount(_account, _token, _amount, _account);

        if (_shouldReduceBnDfex) {
            uint256 bnDfexAmount = IRewardTracker(bonusDfexTracker).claimForAccount(_account, _account);
            if (bnDfexAmount > 0) {
                IRewardTracker(feeDfexTracker).stakeForAccount(_account, _account, bnDfex, bnDfexAmount);
            }

            uint256 stakedBnDfex = IRewardTracker(feeDfexTracker).depositBalances(_account, bnDfex);
            if (stakedBnDfex > 0) {
                uint256 reductionAmount = stakedBnDfex.mul(_amount).div(balance);
                IRewardTracker(feeDfexTracker).unstakeForAccount(_account, bnDfex, reductionAmount, _account);
                IMintable(bnDfex).burn(_account, reductionAmount);
            }
        }

        emit UnstakeDfex(_account, _token, _amount);
    }
}
