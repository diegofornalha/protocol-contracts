// SPDX-License-Identifier: MIT

pragma solidity >=0.6.2 <0.8.0;
pragma abicoder v2;

import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
//import "@rarible/lib-broken-line/contracts/LibBrokenLine.sol"; //todo delete comment use @rarible/lib-broken-line/
import "../../broken-line/contracts/LibBrokenLine.sol"; //todo delete this line

contract Staking {
    using SafeMathUpgradeable for uint;
    using LibBrokenLine for BrokenLineDomain.BrokenLine;

    uint256 constant WEEK = 604800;                 //seconds one week
    uint256 constant STARTING_POINT_WEEK = 2676;    //starting point week (Staking Epoch begining)
    uint256 constant TWO_YEAR_WEEKS = 104;          //two year weeks
    uint256 constant WEEK_ST_FORMULA_MUL = 1000;    //week multiplier
    ERC20Upgradeable public token;
    uint public id;                                 //id Line, successfully added to BrokenLine

    struct Locks {
        BrokenLineDomain.BrokenLine balance;   //line of stRari balance
        BrokenLineDomain.BrokenLine locked;    //locked amount (RARI)
        uint amount;                           //user RARI (lockedAmount+ amountready for transferBack)
    }

    mapping (address => Locks) locks;                   //address User - Lock
    mapping (uint => address) deposits;                 //idLock address User
    BrokenLineDomain.BrokenLine public totalSupplyLine; //total stRARI balance

    constructor(ERC20Upgradeable _token) public {
        token = _token;
    }

    function createLock(address account, uint amount, uint slope, uint cliff) public returns(uint) {
        if (amount == 0) {
            return 0;
        }
        uint newFinishTime = amount.div(slope).add(cliff);
        require(newFinishTime <= TWO_YEAR_WEEKS, "New finish line time more, than two years");
        (uint stAmount, uint stSlope) = getStake(amount, slope, cliff);
        BrokenLineDomain.Line memory line = BrokenLineDomain.Line(roundTimestamp(block.timestamp), stAmount, stSlope);
        BrokenLineDomain.Line memory lineLocked = BrokenLineDomain.Line(roundTimestamp(block.timestamp), amount, slope);

        id++;
        totalSupplyLine.add(id, line, cliff);

        locks[account].balance.add(id, line, cliff);
        locks[account].locked.add(id, lineLocked, cliff);
        deposits[id] = account;
        locks[account].amount = locks[account].amount.add(amount);
        require(token.transferFrom(account, address(this), amount), "failure while transferring");
        return id;

        // как меняется lock общий, когда юзер приходит/уходит/меняет
        // 1. нужно применить пропущенные изменения (окончания локов)
        // 2. если добавляем, то
    }

    function totalSupply() public returns (uint) {
        if (totalSupplyLine.initial.start == 0) { //no lock
            return 0;
        }
        totalSupplyLine.update(roundTimestamp(block.timestamp));
        return totalSupplyLine.initial.bias;
    }

    function balanceOf(address account) public returns (uint) {
        if (locks[account].balance.initial.start == 0) { //no lock
            return 0;
        }
        locks[account].balance.update(roundTimestamp(block.timestamp));
        return locks[account].balance.initial.bias;
    }

    function withdraw() public  {
        locks[msg.sender].locked.update(roundTimestamp(block.timestamp));
        uint value = locks[msg.sender].amount.sub(locks[msg.sender].locked.initial.bias);
        if (value > 0) {
            locks[msg.sender].amount = locks[msg.sender].amount.sub(value);
            require(token.transfer(msg.sender, value), "failure while transferring");
        }
        //todo Lock delete
    }

    function restake(uint idLock, uint newAmount, uint newSlope, uint newCliff) public returns (uint) {
        address account = deposits[idLock];
        uint blockTime = roundTimestamp(block.timestamp);
        checkRestake(account, idLock, newAmount, newSlope, newCliff, blockTime);

        locks[account].locked.update(blockTime);
        uint amountToWithdraw = locks[account].amount.sub(locks[account].locked.initial.bias);
        //delete brokenLine ERC20
        uint tailRemoved = locks[account].locked.remove(idLock, blockTime);
        require(tailRemoved <= newAmount, "Impossible to restake: less amount, then now is");

        uint addAmount = newAmount.sub(tailRemoved);
        if (addAmount > amountToWithdraw) { //need more, than ready to withdraw, so need transfer ERC20 to this
            require(token.transferFrom(deposits[idLock], address(this), addAmount.sub(amountToWithdraw)), "failure while transferring");
            locks[account].amount = locks[account].amount.sub(tailRemoved);
            locks[account].amount = locks[account].amount.add(newAmount);
        }
        locks[account].balance.remove(idLock, blockTime);
        totalSupplyLine.remove(idLock, blockTime);
        //add lines
        (uint stAmount, uint stSlope) = getStake(newAmount, newSlope, newCliff);
        BrokenLineDomain.Line memory line = BrokenLineDomain.Line(blockTime, stAmount, stSlope);
        BrokenLineDomain.Line memory lineLocked = BrokenLineDomain.Line(blockTime, newAmount, newSlope);
        id++;
        totalSupplyLine.add(id, line, newCliff);
        locks[account].balance.add(id, line, newCliff);
        locks[account].locked.add(id, lineLocked, newCliff);
        deposits[id] = account;
        return id;
    }

    //new amount and slope
    function getStake(uint amount, uint slope, uint cliff) internal returns (uint, uint){
//        =(0,2+0,8*(cliffPeriod/24)^2+0,5*(0,2+0,8*(slopePeriod/24)^2))*1000 original formula
//        =(1000+((cliffPeriod)^2)*8+((slopePeriod)^2)*4)/1000 formula, that works
        uint cliffPart = cliff.mul(cliff).mul(8);

        uint slopePeriod = amount.div(slope);
        uint tail = amount.mod(slope);
        if (tail > 0) {
            slopePeriod++;
        }
        uint slopePart = slopePeriod.mul(slopePeriod).mul(4);
        uint multipleValue = cliffPart.add(slopePart).add(WEEK_ST_FORMULA_MUL);
        multipleValue = multipleValue.div(WEEK_ST_FORMULA_MUL);
        uint newAmount = amount.mul(multipleValue);
        uint newSlope = newAmount.div(slopePeriod);
        return(newAmount, newSlope);
    }

    function checkRestake(address account, uint id, uint newAmount, uint newSlope, uint newCliff, uint toTime) internal {
        require(account != address(0), "Line already with id already deleted");
        require(locks[account].amount >= locks[account].locked.initial.bias, "Impossible to restake: amount < bias");
        uint newFinishTime = newAmount.div(newSlope).add(newCliff);
        require(newFinishTime <= TWO_YEAR_WEEKS, "New finish line time more, than two years");
        newFinishTime = newFinishTime.add(toTime);
        uint oldFinishTime = locks[account].locked.initiatedLines[id].line.bias.div(locks[account].locked.initiatedLines[id].line.slope);
        oldFinishTime = oldFinishTime.add(locks[account].locked.initiatedLines[id].cliff).add(locks[account].locked.initiatedLines[id].line.start);
        require(oldFinishTime <= newFinishTime, "New line period stake too short");
    }

    function roundTimestamp(uint ts) pure internal returns (uint) {
        return ts.div(WEEK).sub(STARTING_POINT_WEEK);
    }
}