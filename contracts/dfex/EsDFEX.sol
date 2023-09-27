// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "../tokens/MintableBaseToken.sol";

contract EsDFEX is MintableBaseToken {
    constructor() public MintableBaseToken("Escrowed DFEX", "esDFEX", 0) {
    }

    function id() external pure returns (string memory _name) {
        return "esDFEX";
    }
}
