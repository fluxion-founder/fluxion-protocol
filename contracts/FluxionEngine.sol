// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./interfaces/IFluxionAaveAdapter.sol";

contract FluxionEngine is ReentrancyGuard {
    IERC20 public immutable fluxionToken;
    IFluxionAaveAdapter public aaveAdapter;
    address public governance;
    
    uint256 public constant TRANSACTION_FEE = 0.001 ether;
    uint256 public constant REWARD_AMOUNT = 10 * (10**18);
    
    uint256 public totalTransactionsExecuted;
    uint256 public totalFeesCollected;
    
    event TransactionExecuted(address indexed user, bytes data, uint256 reward);
    event BatchExecuted(address indexed user, uint256 count, uint256 totalReward);
    event FeesDeposited(uint256 amount);
    event AdapterConfigured(address indexed adapter);
    event GovernanceTransferred(address indexed oldGovernance, address indexed newGovernance);
    
    modifier onlyGovernance() {
        require(msg.sender == governance, "Only governance");
        _;
    }
    
    constructor(address _tokenAddress) {
        require(_tokenAddress != address(0), "Invalid token address");
        fluxionToken = IERC20(_tokenAddress);
        governance = msg.sender;
    }
    
    function setAaveAdapter(address _aaveAdapter) external onlyGovernance {
        require(_aaveAdapter != address(0), "Invalid adapter");
        require(address(aaveAdapter) == address(0), "Adapter already set");
        aaveAdapter = IFluxionAaveAdapter(_aaveAdapter);
        emit AdapterConfigured(_aaveAdapter);
    }
    
    function execute(bytes calldata data) external payable nonReentrant returns (bool) {
        require(msg.value >= TRANSACTION_FEE, "Insufficient fee");
        require(fluxionToken.balanceOf(address(this)) >= REWARD_AMOUNT, "Insufficient reward pool");
        
        totalTransactionsExecuted++;
        totalFeesCollected += TRANSACTION_FEE;
        
        if (address(aaveAdapter) != address(0)) {
            aaveAdapter.depositToAave{value: TRANSACTION_FEE}();
        }
        
        require(fluxionToken.transfer(msg.sender, REWARD_AMOUNT), "Reward transfer failed");
        
        if (msg.value > TRANSACTION_FEE) {
            (bool refundSuccess, ) = msg.sender.call{value: msg.value - TRANSACTION_FEE}("");
            require(refundSuccess, "Refund failed");
        }
        
        emit TransactionExecuted(msg.sender, data, REWARD_AMOUNT);
        return true;
    }
    
    function executeBatch(bytes[] calldata dataArray) external payable nonReentrant returns (bool) {
        uint256 count = dataArray.length;
        require(count > 0, "Empty batch");
        
        uint256 totalFee = TRANSACTION_FEE * count;
        uint256 totalReward = REWARD_AMOUNT * count;
        
        require(msg.value >= totalFee, "Insufficient fee");
        require(fluxionToken.balanceOf(address(this)) >= totalReward, "Insufficient reward pool");
        
        totalTransactionsExecuted += count;
        totalFeesCollected += totalFee;
        
        if (address(aaveAdapter) != address(0)) {
            aaveAdapter.depositToAave{value: totalFee}();
        }
        
        require(fluxionToken.transfer(msg.sender, totalReward), "Reward transfer failed");
        
        if (msg.value > totalFee) {
            (bool refundSuccess, ) = msg.sender.call{value: msg.value - totalFee}("");
            require(refundSuccess, "Refund failed");
        }
        
        emit BatchExecuted(msg.sender, count, totalReward);
        return true;
    }
    
    function setGovernance(address newGovernance) external onlyGovernance {
        require(newGovernance != address(0), "Invalid governance address");
        address oldGovernance = governance;
        governance = newGovernance;
        emit GovernanceTransferred(oldGovernance, newGovernance);
    }
    
    function getL2TreasuryBalance() external view returns (uint256) {
        if (address(aaveAdapter) == address(0)) {
            return 0;
        }
        return aaveAdapter.getTotalBalance();
    }
    
    receive() external payable {
        emit FeesDeposited(msg.value);
    }
}
