// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;
/// @title Fair community token launch. Prevent rug pulls and ensure fair distribution of tokens.

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "https://github.com/Uniswap/v2-periphery/blob/master/contracts/interfaces/IUniswapV2Router02.sol";

contract CCtoken is ERC20 {
    constructor(uint256 initialSupply) ERC20("CabbageCoin", "CC") {
        _mint(msg.sender, initialSupply);
    }
}

contract LiquidityLock {
    //https://docs.quickswap.exchange/reference/smart-contracts/router02/
    address internal constant quickswapRouter = 0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff;
    IUniswapV2Router02 constant router = IUniswapV2Router02(quickswapRouter);
    CCtoken immutable tokenContract;
    address payable immutable user;
    
    constructor(CCtoken tokenContract_, address payable user_) payable {
        tokenContract = tokenContract_;
        user = user_;
    }
    
    function exitPool() external {
        
        
    }
    
}


contract FairLaunch {
    uint256 constant DEV_STAKE     = 50;   // 1/50 -> 2%, developer gets 2% of coin supply
    uint256 constant TOT_SUPPLY    = 1e9;  // 1 billion total supply
    uint256 constant DEV_AMOUNT    = TOT_SUPPLY/DEV_STAKE;
    uint256 constant PLEDGER_SUPPLY= TOT_SUPPLY - DEV_AMOUNT;
    uint256 constant INIT_AMOUNT   = 1000; // amount of coins pledgers get _immidieatly_ regardles of amount pledged, but only once
    uint    constant DURATION_DAYS = 2 minutes;   // 2 months of presale
    
    CCtoken public immutable tokenContract;
    address public  immutable developer;     //creator address
    uint    public  immutable endTime;       //cannot receive new pledges after this time 
    
    uint256 public totalAmount;
    uint    public pledgersCount;
    mapping(address => uint256) public pledgeAmounts;
    
    error LaunchAlreadyEnded();
    error LaunchNotEndedYet();
    error NoPledge();
    error MultipleWithdraw();
    error DeveloperException();
    
    constructor() {
        developer = msg.sender;
        endTime = block.timestamp + DURATION_DAYS;
        tokenContract = new CCtoken(TOT_SUPPLY);
    }
    
    function giveToDev() external {
        if(msg.sender != developer)
            revert DeveloperException();
            
        //prevent multiple withdraws
        if(tokenContract.balanceOf(msg.sender) != 0)
            revert MultipleWithdraw();
        
        tokenContract.transfer(developer, tokenContract.totalSupply()/DEV_STAKE);
    }
    
    function pledge() external payable {
        if(block.timestamp > endTime)
            revert LaunchAlreadyEnded();
            
        if(msg.value == 0)
            revert NoPledge();
            
        //developer can't pledge otherwise he can't get dev stake
        if(msg.sender == developer)
            revert DeveloperException();
        
        //if first pledge then give initial amount of coins
        if(pledgeAmounts[msg.sender] == 0) {
            tokenContract.transfer(msg.sender, INIT_AMOUNT);
            pledgersCount++;
        }    
        
        pledgeAmounts[msg.sender] += msg.value;
        totalAmount += msg.value;
    }
    
    function claim() external {
        if(block.timestamp < endTime)
            revert LaunchNotEndedYet();
        
        uint256 pledgeStake = pledgeAmounts[msg.sender]; 
        
        if(pledgeStake == 0)
            revert NoPledge();
        
        // available is only amount left after developers cut and initial amount on first pledge
        uint256 availableSupply = PLEDGER_SUPPLY - (pledgersCount * INIT_AMOUNT);
        // pledger gets amount proportional to his pledge relative to all pledges
        uint256 coinStake = availableSupply * pledgeStake / totalAmount;
        tokenContract.transfer(msg.sender, coinStake);
        
        //prevent multiple withdraws
        pledgeAmounts[msg.sender] = 0;
    }
    
}