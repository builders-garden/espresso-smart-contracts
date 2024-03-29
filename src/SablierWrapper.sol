// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import { ISablierV2LockupLinear } from "@sablier/v2-core/src/interfaces/ISablierV2LockupLinear.sol";
import { ISablierV2NFTDescriptor } from "@sablier/v2-core/src/interfaces/ISablierV2NFTDescriptor.sol";
import { LockupLinear, Broker  } from '@sablier/v2-core/src/types/DataTypes.sol';

contract SablierWrapper {
    
    bool initialized;
    address voucherAddress;
    address voucherSource;
    address BNPL;
    uint collectedAmount;



    function initialize(address _voucherSource, uint streamId) external {
        require(!initialized, "Already initialized");
        voucherAddress = msg.sender;
        BNPL = msg.sender;
        voucherSource = _voucherSource;
        initialized = true;
    }

    function withdraw(uint amount) public {
        require(msg.sender == BNPL, "Not us");
        collectedAmount += amount;
        IERC20(voucherAddress).transferFrom(BNPL, address(this), amount);
        IERC20(voucherSource).transfer(BNPL, amount);
    }   

    
    function getRepaidAmount() external view returns (uint){
        // Collected Amount + Actual Balance
        return (IERC20(voucherSource).balanceOf(address(this)) + collectedAmount);
    }

    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4) {}
    
}

