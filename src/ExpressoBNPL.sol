// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;


import '@openzeppelin/contracts/token/ERC721/ERC721.sol';
import '@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol';
import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import "@openzeppelin/contracts/proxy/Clones.sol";
import { ISablierV2LockupLinear } from "@sablier/v2-core/src/interfaces/ISablierV2LockupLinear.sol";
import { ISablierV2NFTDescriptor } from "@sablier/v2-core/src/interfaces/ISablierV2NFTDescriptor.sol";
import { LockupLinear, Broker, Lockup } from '@sablier/v2-core/src/types/DataTypes.sol';
import {SablierWrapper} from './SablierWrapper.sol';

// 1. User deposit nft
// 2. user receives founds
// 3. vault is created
// 4. stream is created and linked to vault
// 5. repayment occours in 4 instllments 
//     a. installments miss penalties are accrued
//     b. liquidation occours if deadline is missed

contract ExpressoBNPL is IERC721Receiver, ERC20 {
    
    ISablierV2LockupLinear sablierLL = ISablierV2LockupLinear(0xFCF737582d167c7D20A336532eb8BCcA8CF8e350);
    ISablierV2NFTDescriptor sablierNFT = ISablierV2NFTDescriptor(0x67e0a126b695DBA35128860cd61926B90C420Ceb);
    IERC20 public USDC = IERC20(0xd9aAEc86B65D86f6A7B5B1b0c42FFA531710b6CA);
    
    
    mapping (uint=>LoanInfo) public s_loanInfo;
    mapping (uint=>uint) public s_streamToInfo;
    address wrapperImplementation;
    address public owner;

    modifier OnlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }


    struct LoanInfo{
        address assetRequested;
        address assetCollateralized;
        uint requestedAmount;
        uint collateralId;
        uint deadline; 
        address wrapperAddress;
    }

    uint loanCounter;


    constructor()ERC20("BNPLVoucher", "vBNPL"){
        wrapperImplementation = address(new SablierWrapper());
        owner = msg.sender;
    }  

    function cloneImpl(address redeemableAddress, uint streamId) public returns(address) {
        address payable cloneAddress = payable(
            Clones.clone(wrapperImplementation)
        );
        SablierWrapper(cloneAddress).initialize(redeemableAddress, streamId);
        
        return cloneAddress;
    }
    
    
    function _createRepaymentStream(uint start, uint end, uint amount, address redeemableAsset) public returns(uint256) {

        _mint(address(this), amount);
        loanCounter += 1;
        
        LockupLinear.Range memory range = LockupLinear.Range(uint40(start), uint40(start), uint40(end));
        Broker memory undefinedBroker;
        LockupLinear.CreateWithRange memory params = LockupLinear.CreateWithRange(
            msg.sender,
            address(this),
            uint128(amount),
            IERC20(address(this)), 
            false,
            true,
            range,
            undefinedBroker
            );
        
        IERC20(address(this)).approve(address(sablierLL), amount);
        ( uint streamId ) = sablierLL.createWithRange(params); 
        s_streamToInfo[streamId] = loanCounter;
        address wrapper = cloneImpl(redeemableAsset, streamId);
        LoanInfo storage loanInfo = s_loanInfo[loanCounter];
        loanInfo.wrapperAddress = 0x037eDa3aDB1198021A9b2e88C22B464fD38db3f3;
        return streamId;
    }
    
    
    function getLoanWithSablier(uint start, uint end, uint amount, address assetBorrowed, address assetCollateral, uint tokenId) public {
        //require((end-start) < 1 months, "Duration has to be less than a month");
        // require sablier nft renounced, transferable etc;
        
        IERC20(assetBorrowed).transfer(msg.sender, amount);
        IERC721(assetCollateral).safeTransferFrom(msg.sender, address(this), tokenId);
        _createRepaymentStream(start, end, amount, assetBorrowed);
        
        LoanInfo memory loanInfo = LoanInfo(assetBorrowed, assetCollateral, amount, tokenId, end, 0x037eDa3aDB1198021A9b2e88C22B464fD38db3f3);  
        s_loanInfo[loanCounter] = loanInfo;
    }

    function isSablierCancelDisabled(LockupLinear.Stream memory stream) internal returns (bool){
        return stream.isCancelable;
    } 

    function isSablierTransferable(LockupLinear.Stream memory stream) internal returns (bool){
        return stream.isTransferable;
    }

    function isElegibleSablier(uint streamId) public returns (bool){
        LockupLinear.Stream memory stream;
        stream = sablierLL.getStream(streamId);
        bool cancelable = isSablierCancelDisabled(stream);
        bool transferable = isSablierTransferable(stream);
        return (!cancelable && transferable);
    }
    function getSablierCurrentValue(uint streamId) public returns (uint) {
        LockupLinear.Stream memory stream;
        stream = sablierLL.getStream(streamId);
        Lockup.Amounts memory amounts = stream.amounts;
        return (amounts.deposited - amounts.withdrawn);
    }

    // function getLoanWithElegibleNFT(uint start, uint end, uint amount, address assetBorrowed, address assetCollateral, uint tokenId) public {

    // }


    function collectFromSablierAndUnwrap(uint streamId) public {
        uint balanceBefore = balanceOf(address(this));
        sablierLL.withdrawMax(streamId, address(this));
        uint collected = balanceOf(address(this)) - balanceBefore;
        address wrap = s_loanInfo[streamId].wrapperAddress;
        IERC20(address(this)).approve(wrap, collected);
        SablierWrapper(wrap).withdraw(collected);
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
