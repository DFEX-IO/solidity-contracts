// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "../libraries/math/SafeMath.sol";
import "../libraries/token/IERC20.sol";

import "../core/interfaces/IDlpManager.sol";

import "./interfaces/IRewardTracker.sol";
import "./interfaces/IRewardTracker.sol";

// provide a way to transfer staked DLP tokens by unstaking from the sender
// and staking for the receiver
// tests in RewardRouterV2.js
contract StakedDlp {
    using SafeMath for uint256;

    string public constant name = "StakedDlp";
    string public constant symbol = "sDLP";
    uint8 public constant decimals = 18;

    address public dlp;
    IDlpManager public dlpManager;
    address public stakedDlpTracker;
    address public feeDlpTracker;

    mapping (address => mapping (address => uint256)) public allowances;

    event Approval(address indexed owner, address indexed spender, uint256 value);

    constructor(
        address _dlp,
        IDlpManager _dlpManager,
        address _stakedDlpTracker,
        address _feeDlpTracker
    ) public {
        dlp = _dlp;
        dlpManager = _dlpManager;
        stakedDlpTracker = _stakedDlpTracker;
        feeDlpTracker = _feeDlpTracker;
    }

    function allowance(address _owner, address _spender) external view returns (uint256) {
        return allowances[_owner][_spender];
    }

    function approve(address _spender, uint256 _amount) external returns (bool) {
        _approve(msg.sender, _spender, _amount);
        return true;
    }

    function transfer(address _recipient, uint256 _amount) external returns (bool) {
        _transfer(msg.sender, _recipient, _amount);
        return true;
    }

    function transferFrom(address _sender, address _recipient, uint256 _amount) external returns (bool) {
        uint256 nextAllowance = allowances[_sender][msg.sender].sub(_amount, "StakedDlp: transfer amount exceeds allowance");
        _approve(_sender, msg.sender, nextAllowance);
        _transfer(_sender, _recipient, _amount);
        return true;
    }

    function balanceOf(address _account) external view returns (uint256) {
        IRewardTracker(stakedDlpTracker).depositBalances(_account, dlp);
    }

    function totalSupply() external view returns (uint256) {
        IERC20(stakedDlpTracker).totalSupply();
    }

    function _approve(address _owner, address _spender, uint256 _amount) private {
        require(_owner != address(0), "StakedDlp: approve from the zero address");
        require(_spender != address(0), "StakedDlp: approve to the zero address");

        allowances[_owner][_spender] = _amount;

        emit Approval(_owner, _spender, _amount);
    }

    function _transfer(address _sender, address _recipient, uint256 _amount) private {
        require(_sender != address(0), "StakedDlp: transfer from the zero address");
        require(_recipient != address(0), "StakedDlp: transfer to the zero address");

        require(
            dlpManager.lastAddedAt(_sender).add(dlpManager.cooldownDuration()) <= block.timestamp,
            "StakedDlp: cooldown duration not yet passed"
        );

        IRewardTracker(stakedDlpTracker).unstakeForAccount(_sender, feeDlpTracker, _amount, _sender);
        IRewardTracker(feeDlpTracker).unstakeForAccount(_sender, dlp, _amount, _sender);

        IRewardTracker(feeDlpTracker).stakeForAccount(_sender, _recipient, dlp, _amount);
        IRewardTracker(stakedDlpTracker).stakeForAccount(_recipient, _recipient, feeDlpTracker, _amount);
    }
}
