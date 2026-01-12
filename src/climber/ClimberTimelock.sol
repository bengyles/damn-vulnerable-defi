// SPDX-License-Identifier: MIT
// Damn Vulnerable DeFi v4 (https://damnvulnerabledefi.xyz)
pragma solidity =0.8.25;

import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {ClimberTimelockBase} from "./ClimberTimelockBase.sol";
import {ADMIN_ROLE, PROPOSER_ROLE, MAX_TARGETS, MIN_TARGETS, MAX_DELAY} from "./ClimberConstants.sol";
import {
    InvalidTargetsCount,
    InvalidDataElementsCount,
    InvalidValuesCount,
    OperationAlreadyKnown,
    NotReadyForExecution,
    CallerNotTimelock,
    NewDelayAboveMax
} from "./ClimberErrors.sol";

/**
 * @title ClimberTimelock
 * @author
 */
contract ClimberTimelock is ClimberTimelockBase {
    using Address for address;

    /**
     * @notice Initial setup for roles and timelock delay.
     * @param admin address of the account that will hold the ADMIN_ROLE role
     * @param proposer address of the account that will hold the PROPOSER_ROLE role
     */
    constructor(address admin, address proposer) {
        _setRoleAdmin(ADMIN_ROLE, ADMIN_ROLE);
        _setRoleAdmin(PROPOSER_ROLE, ADMIN_ROLE);

        _grantRole(ADMIN_ROLE, admin);
        _grantRole(ADMIN_ROLE, address(this)); // self administration
        _grantRole(PROPOSER_ROLE, proposer);

        delay = 1 hours;
    }

    function schedule(
        address[] calldata targets,
        uint256[] calldata values,
        bytes[] calldata dataElements,
        bytes32 salt
    ) external onlyRole(PROPOSER_ROLE) {
        if (targets.length == MIN_TARGETS || targets.length >= MAX_TARGETS) {
            revert InvalidTargetsCount();
        }

        if (targets.length != values.length) {
            revert InvalidValuesCount();
        }

        if (targets.length != dataElements.length) {
            revert InvalidDataElementsCount();
        }

        bytes32 id = getOperationId(targets, values, dataElements, salt);

        if (getOperationState(id) != OperationState.Unknown) {
            revert OperationAlreadyKnown(id);
        }

        operations[id].readyAtTimestamp = uint64(block.timestamp) + delay;
        operations[id].known = true;
    }

    /**
     * Anyone can execute what's been scheduled via `schedule`
     */
    function execute(address[] calldata targets, uint256[] calldata values, bytes[] calldata dataElements, bytes32 salt)
        external
        payable
    {
        if (targets.length <= MIN_TARGETS) {
            revert InvalidTargetsCount();
        }

        if (targets.length != values.length) {
            revert InvalidValuesCount();
        }

        if (targets.length != dataElements.length) {
            revert InvalidDataElementsCount();
        }

        bytes32 id = getOperationId(targets, values, dataElements, salt);

        // @audit since this contract is also the admin, anyone can call functions to this contract to schedule, delay, set role permissions and possibly even directly execute transfers!
        for (uint8 i = 0; i < targets.length; ++i) {
            targets[i].functionCallWithValue(dataElements[i], values[i]);
        }

        // @audit state is checked after calling the functions, so we can schedule it first by calling the schedule function (since this contract is also the admin we may have to set the proposer as well), execute an upgrade for the vault (which sets the attacker as the sweeper) 
        if (getOperationState(id) != OperationState.ReadyForExecution) {
            revert NotReadyForExecution(id);
        }

        operations[id].executed = true;
    }

    function updateDelay(uint64 newDelay) external {
        if (msg.sender != address(this)) {
            revert CallerNotTimelock();
        }

        if (newDelay > MAX_DELAY) {
            revert NewDelayAboveMax();
        }

        delay = newDelay;
    }
}
