// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract FluxionVesting is ReentrancyGuard {
    using SafeERC20 for IERC20;
    
    address public immutable beneficiary;
    uint256 public immutable vestingDuration;
    uint256 public immutable startTime;
    
    mapping(address => uint256) public released;
    
    event TokensReleased(address indexed token, uint256 amount);
    
    constructor(address _beneficiary, uint256 _vestingDurationSeconds) {
        require(_beneficiary != address(0), "Invalid beneficiary");
        require(_vestingDurationSeconds > 0, "Invalid duration");
        
        beneficiary = _beneficiary;
        vestingDuration = _vestingDurationSeconds;
        startTime = block.timestamp;
    }
    
    function release(address token) external nonReentrant {
        uint256 releasable = releasableAmount(token);
        require(releasable > 0, "No tokens to release");
        
        released[token] += releasable;
        
        IERC20(token).safeTransfer(beneficiary, releasable);
        
        emit TokensReleased(token, releasable);
    }
    
    function releasableAmount(address token) public view returns (uint256) {
        return vestedAmount(token) - released[token];
    }
    
    function vestedAmount(address token) public view returns (uint256) {
        uint256 totalBalance = IERC20(token).balanceOf(address(this)) + released[token];
        
        if (block.timestamp < startTime) {
            return 0;
        } else if (block.timestamp >= startTime + vestingDuration) {
            return totalBalance;
        } else {
            return (totalBalance * (block.timestamp - startTime)) / vestingDuration;
        }
    }
}
