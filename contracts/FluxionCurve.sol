// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

contract FluxionCurve is ReentrancyGuard {
    IERC20 public immutable fluxionToken;
    
    uint256 private constant INITIAL_PRICE = 0.000001 ether;
    uint256 private constant CURVE_COEFFICIENT = 1e9;
    uint256 private constant SCALING_FACTOR = 1e18;
    
    uint256 public totalSold;
    
    event TokensPurchased(address indexed buyer, uint256 tokenAmount, uint256 maticAmount);
    event TokensSold(address indexed seller, uint256 tokenAmount, uint256 maticAmount);
    
    constructor(address _tokenAddress) {
        require(_tokenAddress != address(0), "Invalid token address");
        fluxionToken = IERC20(_tokenAddress);
    }
    
    function getCurrentPrice() public view returns (uint256) {
        uint256 supply = totalSold / SCALING_FACTOR;
        uint256 priceIncrease = (supply * supply * supply * CURVE_COEFFICIENT) / (SCALING_FACTOR * SCALING_FACTOR);
        return INITIAL_PRICE + priceIncrease;
    }
    
    function calculatePurchaseCost(uint256 tokenAmount) public view returns (uint256) {
        uint256 currentSupply = totalSold;
        uint256 newSupply = currentSupply + tokenAmount;
        
        uint256 s1 = currentSupply / SCALING_FACTOR;
        uint256 s2 = newSupply / SCALING_FACTOR;
        
        uint256 integralCurrent = (s1 * s1 * s1 * s1 * CURVE_COEFFICIENT) / (4 * SCALING_FACTOR * SCALING_FACTOR);
        uint256 integralNew = (s2 * s2 * s2 * s2 * CURVE_COEFFICIENT) / (4 * SCALING_FACTOR * SCALING_FACTOR);
        
        uint256 cost = (integralNew - integralCurrent) + (INITIAL_PRICE * tokenAmount / SCALING_FACTOR);
        
        return cost;
    }
    
    function buy(uint256 tokenAmount) external payable nonReentrant {
        require(tokenAmount > 0, "Amount must be positive");
        require(fluxionToken.balanceOf(address(this)) >= tokenAmount, "Insufficient curve balance");
        
        uint256 cost = calculatePurchaseCost(tokenAmount);
        require(msg.value >= cost, "Insufficient MATIC sent");
        
        totalSold += tokenAmount;
        
        require(fluxionToken.transfer(msg.sender, tokenAmount), "Token transfer failed");
        
        if (msg.value > cost) {
            (bool refundSuccess, ) = msg.sender.call{value: msg.value - cost}("");
            require(refundSuccess, "Refund failed");
        }
        
        emit TokensPurchased(msg.sender, tokenAmount, cost);
    }
    
    function sell(uint256 tokenAmount) external nonReentrant {
        require(tokenAmount > 0, "Amount must be positive");
        require(totalSold >= tokenAmount, "Insufficient sold supply");
        
        uint256 refund = calculateSellRefund(tokenAmount);
        require(address(this).balance >= refund, "Insufficient MATIC in curve");
        
        totalSold -= tokenAmount;
        
        require(fluxionToken.transferFrom(msg.sender, address(this), tokenAmount), "Token transfer failed");
        
        (bool success, ) = msg.sender.call{value: refund}("");
        require(success, "MATIC transfer failed");
        
        emit TokensSold(msg.sender, tokenAmount, refund);
    }
    
    function calculateSellRefund(uint256 tokenAmount) public view returns (uint256) {
        uint256 newSupply = totalSold - tokenAmount;
        uint256 currentSupply = totalSold;
        
        uint256 s1 = newSupply / SCALING_FACTOR;
        uint256 s2 = currentSupply / SCALING_FACTOR;
        
        uint256 integralNew = (s1 * s1 * s1 * s1 * CURVE_COEFFICIENT) / (4 * SCALING_FACTOR * SCALING_FACTOR);
        uint256 integralCurrent = (s2 * s2 * s2 * s2 * CURVE_COEFFICIENT) / (4 * SCALING_FACTOR * SCALING_FACTOR);
        
        uint256 refund = (integralCurrent - integralNew) + (INITIAL_PRICE * tokenAmount / SCALING_FACTOR);
        
        return refund;
    }
    
    receive() external payable {}
}
