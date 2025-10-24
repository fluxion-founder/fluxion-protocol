// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./interfaces/IFluxionAaveAdapter.sol";

interface IAavePool {
    function supply(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external;
    function withdraw(address asset, uint256 amount, address to) external returns (uint256);
}

interface IWMATIC {
    function deposit() external payable;
    function withdraw(uint256) external;
    function approve(address spender, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

interface IAToken {
    function balanceOf(address account) external view returns (uint256);
}

contract FluxionAaveAdapter is IFluxionAaveAdapter, ReentrancyGuard {
    address public immutable fluxionEngine;
    
    IAavePool public constant AAVE_POOL = IAavePool(0x794a61358D6845594F94dc1DB02A252b5b4814aD);
    IWMATIC public constant WMATIC = IWMATIC(0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270);
    IAToken public constant amWMATIC = IAToken(0x6d80113e533a2C0fe82EaBD35f1875DcEA89Ea97);
    
    event DepositedToAave(uint256 amount);
    event WithdrawnFromAave(address indexed recipient, uint256 amount);
    
    modifier onlyEngine() {
        require(msg.sender == fluxionEngine, "Only FluxionEngine");
        _;
    }
    
    constructor(address _fluxionEngine) {
        require(_fluxionEngine != address(0), "Invalid engine address");
        fluxionEngine = _fluxionEngine;
    }
    
    function depositToAave() external payable override onlyEngine nonReentrant {
        require(msg.value > 0, "No MATIC sent");
        
        WMATIC.deposit{value: msg.value}();
        
        uint256 wmaticBalance = WMATIC.balanceOf(address(this));
        require(wmaticBalance >= msg.value, "WMATIC deposit failed");
        
        WMATIC.approve(address(AAVE_POOL), msg.value);
        
        AAVE_POOL.supply(address(WMATIC), msg.value, address(this), 0);
        
        emit DepositedToAave(msg.value);
    }
    
    function withdrawFromAave(address recipient, uint256 amount) external override onlyEngine nonReentrant returns (uint256) {
        require(recipient != address(0), "Invalid recipient");
        require(amount > 0, "Invalid amount");
        
        uint256 withdrawn = AAVE_POOL.withdraw(address(WMATIC), amount, address(this));
        
        WMATIC.withdraw(withdrawn);
        
        (bool success, ) = recipient.call{value: withdrawn}("");
        require(success, "MATIC transfer failed");
        
        emit WithdrawnFromAave(recipient, withdrawn);
        return withdrawn;
    }
    
    function getTotalBalance() external view override returns (uint256) {
        return amWMATIC.balanceOf(address(this));
    }
    
    receive() external payable {}
}
