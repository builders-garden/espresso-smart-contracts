// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;


import '@openzeppelin/contracts/token/ERC721/ERC721.sol';
import '@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol';
import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import "@openzeppelin/contracts/proxy/Clones.sol";
import { ISablierV2LockupLinear } from "@sablier/v2-core/src/interfaces/ISablierV2LockupLinear.sol";
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
    

    event Borrowed(address indexed borrower, uint deadline, uint loanId, uint amount, address collateralNftAddress, uint collateralTokenId);
    event ClaimRepaid(address indexed borrower, uint loanId, address collateralNftAddress, uint collateralTokenId);


    ISablierV2LockupLinear sablierLL = ISablierV2LockupLinear(0xbd7AAA2984c0a887E93c66baae222749883763d3);
  
    IERC20 public USDC = IERC20(0x036cbd53842c5426634e7929541ec2318f3dcf7e);
    
    
    mapping (uint=>LoanInfo) public s_loanInfo;
    mapping (uint=>uint) public s_streamToInfo;
    mapping (uint=>address) public s_idToWrapper;
    address wrapperImplementation;
    address public owner;

    modifier OnlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    struct LoanInfo{
        address assetRequested;
        address assetCollateralized;
        address borrower;
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
        
        s_idToWrapper[loanCounter] = wrapper;
        
        return streamId;
    }
    
    
    function getLoanWithSablier(uint amount, address assetBorrowed, address assetCollateral, uint tokenId, address merchant) public returns (uint){
        //require((end-start) < 1 months, "Duration has to be less than a month");
        // require sablier nft renounced, transferable etc;
        
        IERC20(assetBorrowed).transfer(merchant, amount);
        uint deadline = block.timestamp + 30 days;
        IERC721(assetCollateral).safeTransferFrom(msg.sender, address(this), tokenId);
        _createRepaymentStream(block.timestamp, block.timestamp + 30 days, amount, assetBorrowed);
        LoanInfo memory loanInfo = LoanInfo(assetBorrowed, assetCollateral, msg.sender, amount, tokenId, block.timestamp + 30 days, address(0));  
        s_loanInfo[loanCounter] = loanInfo;

        emit Borrowed(msg.sender, deadline, loanCounter, amount, assetCollateral, tokenId);
        
        return loanCounter;
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


    function collectFromSablierAndUnwrap(uint streamId, uint loanId) public {
        uint balanceBefore = balanceOf(address(this));
        sablierLL.withdrawMax(streamId, address(this));
        uint collected = balanceOf(address(this)) - balanceBefore;
        address wrapper = s_idToWrapper[loanId];
        IERC20(address(this)).approve(wrapper, collected);
        SablierWrapper(wrapper).withdraw(collected);
    }

    function claimRepaidSablierCollateral(uint loanId) public {
        LoanInfo memory loanInfo = s_loanInfo[loanId];
        uint requestedAmount = loanInfo.requestedAmount;
        uint streamId = loanInfo.collateralId;
        address collateralAddress = loanInfo.assetCollateralized;
        require(msg.sender == loanInfo.borrower);
        require(checkRepayment(loanId) >= requestedAmount, "not repaid");
        IERC721(collateralAddress).safeTransferFrom(address(this), msg.sender, streamId);

        emit ClaimRepaid(msg.sender, loanId, collateralAddress, streamId);
    }

    function checkRepayment(uint loanId) public view returns (uint repaidAmount) {
        address wrapper = s_idToWrapper[loanId];
        return SablierWrapper(wrapper).getRepaidAmount();
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

