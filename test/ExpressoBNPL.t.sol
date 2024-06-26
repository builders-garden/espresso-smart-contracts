// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {ExpressoBNPL} from '../src/ExpressoBNPL.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC721/IERC721.sol';
import '@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol';
import { ISablierV2LockupLinear } from "@sablier/v2-core/src/interfaces/ISablierV2LockupLinear.sol";
import { ISablierV2NFTDescriptor } from "@sablier/v2-core/src/interfaces/ISablierV2NFTDescriptor.sol";
import { LockupLinear, Broker  } from '@sablier/v2-core/src/types/DataTypes.sol';
// https://base-rpc.publicnode.com

contract ExpressoBNPLTest is Test, IERC721Receiver{

    ISablierV2LockupLinear sablierLL = ISablierV2LockupLinear(0xbd7AAA2984c0a887E93c66baae222749883763d3);
    ISablierV2NFTDescriptor sablierNFT = ISablierV2NFTDescriptor(0xb2b4b1E69B16411AEBD30c8EA5aB395E13069160);

    address usdcAddress = 0x036CbD53842c5426634e7929541eC2318f3dCF7e; // circle usdc on base sepolia 
    address LL = 0xbd7AAA2984c0a887E93c66baae222749883763d3;

    ExpressoBNPL exp;

    function setUp() public {
        exp = new ExpressoBNPL();
    }

    function test_CreateRepaymentStream()  public{
        uint amount = 1e6;
        deal(address(exp), address(this), 1e30);
        IERC20(address(exp)).approve(address(exp), 1e30);
          
        uint streamId = exp._createRepaymentStream(block.timestamp, block.timestamp + 1 days, 1e10, address(usdcAddress));
        streamId = exp._createRepaymentStream(block.timestamp, block.timestamp + 1 days, 1e10, address(usdcAddress));
        console.logAddress(IERC721(address(LL)).ownerOf(streamId));
        console.logAddress( address(this));
    }


    function test_getLoanWithSablier() public {
        
        uint streamId = getSablierNFT();
        console.logUint(IERC20(usdcAddress).balanceOf(address(this)));
        IERC721(address(LL)).setApprovalForAll(address(exp), true);
        exp.getLoanWithSablier(1e10, usdcAddress, address(LL), streamId, address(this));
          console.logUint(IERC20(usdcAddress).balanceOf(address(this)));
        (
        address assetRequested,
        address assetCollateralized,
        address borrower,
        uint requestedAmount,
        uint collateralId,
        uint deadline,
        ) = exp.s_loanInfo(1);
        console.logAddress(borrower);

      
       
    }

    function getSablierNFT() internal returns (uint){   
        deal(usdcAddress, address(this), 1e30);
        deal(usdcAddress, address(exp), 1e30);
        IERC20(usdcAddress).approve(LL, 1e30);
        LockupLinear.Range memory range = LockupLinear.Range(uint40(block.timestamp), uint40(block.timestamp), uint40(block.timestamp+1 days));
        Broker memory undefinedBroker;
        LockupLinear.CreateWithRange memory params = LockupLinear.CreateWithRange(
            msg.sender,
            address(this),
            uint128(1e30),
            IERC20(usdcAddress), 
            false,
            true,
            range,
            undefinedBroker
            );
        ( uint streamId ) = sablierLL.createWithRange(params);
        return streamId;
    }

    function test_views() public {
        uint streamId = getSablierNFT();
        uint currentValue = exp.getSablierCurrentValue(streamId);
        console.logUint(currentValue);
    }

    function test_isElegibleSablier() public {
        uint streamId = getSablierNFT();
        bool elegible = exp.isElegibleSablier(streamId);
    }
    
    function test_Collect() public {
        
        deal(address(exp), address(this), 1e10);
        IERC20(address(exp)).approve(address(exp), 1e10);
          
        uint streamId = getSablierNFT();
        
        IERC721(address(LL)).setApprovalForAll(address(exp), true);
        uint loanId = exp.getLoanWithSablier(1e10, usdcAddress, address(LL), streamId, address(1234));
       
        vm.warp(block.timestamp + 2 hours);


        address wrapper = exp.s_idToWrapper(loanId);

        deal(usdcAddress, wrapper, 1e10);
        exp.collectFromSablierAndUnwrap(streamId, loanId);
    }



    function test_Repaid() public {
        uint streamId = getSablierNFT();
        IERC721(address(LL)).setApprovalForAll(address(exp), true);
        uint loanId = exp.getLoanWithSablier(1e10, usdcAddress, address(LL), streamId, address(1234));
        address wrapper = exp.s_idToWrapper(1);
    
        vm.expectRevert();
        exp.claimRepaidSablierCollateral(loanId);

        deal(usdcAddress, address(this), 1e10);
        IERC20(usdcAddress).approve(address(exp), 1e10);
        exp.claimRepaidSablierCollateral(loanId);
    }
   




    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure override returns (bytes4) {
        return
            bytes4(
                keccak256("onERC721Received(address,address,uint256,bytes)")
            );
    }
}   
