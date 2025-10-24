// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

contract FluxionToken is ERC20, ERC20Burnable {
    uint256 public constant TOTAL_SUPPLY = 1_000_000_000 * (10**18);

    constructor() ERC20("Fluxion Protocol", "FLUXION") {
        _mint(msg.sender, TOTAL_SUPPLY);
    }
}
