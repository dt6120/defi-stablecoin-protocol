// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";

interface IDecentralizedStablecoin is IERC20 {
    error DecentralizedStablecoin__ZeroAmountNotAllowed();

    function burn(uint256 amount) external;
    function mint(address to, uint256 amount) external returns (bool);
}
