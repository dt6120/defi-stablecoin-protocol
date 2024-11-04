// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {ERC20Burnable, ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title DecentralizedStablecoin
 * @author Dhruv Takwal
 *
 * @notice This contract is an ERC20 implementation meant to be used as a stablecoin and governed by the DSCEngine.
 *
 * @dev The stablecoin has the following properties:
 * Collateral: Exogenous (wETH & wBTC)
 * Minting: Algorithmic
 * Relative stability: Pegged to USD
 *
 */
contract DecentralizedStablecoin is ERC20Burnable, Ownable {
    error DecentralizedStablecoin__ZeroAmountNotAllowed();

    constructor() ERC20("DecentralizedStablecoin", "DSC") Ownable(msg.sender) {}

    function burn(uint256 amount) public override(ERC20Burnable) onlyOwner {
        if (amount == 0) {
            revert DecentralizedStablecoin__ZeroAmountNotAllowed();
        }

        super.burn(amount);
    }

    function mint(address to, uint256 amount) external onlyOwner returns (bool) {
        if (amount == 0) {
            revert DecentralizedStablecoin__ZeroAmountNotAllowed();
        }

        _mint(to, amount);
        return true;
    }
}
