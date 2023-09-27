// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "../tokens/MintableBaseToken.sol";

contract DLP is MintableBaseToken {
    constructor() public MintableBaseToken("DFEX LP", "DLP", 0) {
    }

    function id() external pure returns (string memory _name) {
        return "DLP";
    }
}
