// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "../tokens/MintableBaseToken.sol";

contract DFEX is MintableBaseToken {
    constructor() public MintableBaseToken("DFEX", "DFEX", 0) {
    }

    function id() external pure returns (string memory _name) {
        return "DFEX";
    }
}
