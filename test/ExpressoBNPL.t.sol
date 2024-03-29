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

    ISablierV2LockupLinear sablierLL = ISablierV2LockupLinear(0xFCF737582d167c7D20A336532eb8BCcA8CF8e350);
    ISablierV2NFTDescriptor sablierNFT = ISablierV2NFTDescriptor(0x67e0a126b695DBA35128860cd61926B90C420Ceb);

    address usdcAddress = 0xd9aAEc86B65D86f6A7B5B1b0c42FFA531710b6CA;
    address LL = 0xFCF737582d167c7D20A336532eb8BCcA8CF8e350;
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
        
        IERC721(address(LL)).setApprovalForAll(address(exp), true);
        exp.getLoanWithSablier(block.timestamp, block.timestamp + 1 days, 1e10, usdcAddress, address(LL), streamId);
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
          
        uint streamId = exp._createRepaymentStream(block.timestamp, block.timestamp + 1 days, 1e10, address(usdcAddress));
        
        vm.warp(block.timestamp + 1 days);



        (, , , , , address wrapper) = exp.s_loanInfo(exp.s_streamToInfo(streamId)); 


        deal(usdcAddress, 0x037eDa3aDB1198021A9b2e88C22B464fD38db3f3, 1e10);
        exp.collectFromSablierAndUnwrap(streamId);
        console.logAddress(wrapper);
        console.logUint(IERC20(usdcAddress).balanceOf(wrapper));
        console.logUint(IERC20(address(exp)).balanceOf(wrapper));
        console.logUint(IERC20(usdcAddress).balanceOf(address(exp)));
        
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
