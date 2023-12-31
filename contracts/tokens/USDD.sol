// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "./interfaces/IUSDD.sol";
import "./YieldToken.sol";

contract USDD is YieldToken, IUSDD {

    mapping (address => bool) public vaults;

    modifier onlyVault() {
        require(vaults[msg.sender], "USDD: forbidden");
        _;
    }

    constructor(address _vault) public YieldToken("USD DFEX", "USDD", 0) {
        vaults[_vault] = true;
    }

    function addVault(address _vault) external override onlyGov {
        vaults[_vault] = true;
    }

    function removeVault(address _vault) external override onlyGov {
        vaults[_vault] = false;
    }

    function mint(address _account, uint256 _amount) external override onlyVault {
        _mint(_account, _amount);
    }

    function burn(address _account, uint256 _amount) external override onlyVault {
        _burn(_account, _amount);
    }
}
