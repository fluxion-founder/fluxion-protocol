// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IFluxionAaveAdapter {
    function depositToAave() external payable;
    function withdrawFromAave(address recipient, uint256 amount) external returns (uint256);
    function getTotalBalance() external view returns (uint256);
}
