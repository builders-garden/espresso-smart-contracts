# Commands 
If you happen to test contracts add fork-url as follows:

```
forge test --fork-url http://sepolia.base.org     
```

# How it works

The **Buy Now Pay Later** feature has been built with Sablier NFTs. We created a custom contract owned by Espresso that allows the customer to select and lock one of their Stream NFTs (e.g. the stream representing their payroll). According to the value of the stream that they deposit and lock, Espresso grants them a loan, paying the merchant in advance on behalf of the customer and expecting the customer to pay their debt back within 4 months. If their debt is extinguished before the deadline, they automatically get back their Stream NFT, otherwise their NFT gets liquidated (i.e. Espresso can claim it).

- **Sablier**: we used Sablier NFTs as collaterals to grant customers a loan. Sablier NFTs can represent payrolls for example, and it's one the best permissionless credential that allows Espresso to verify and trust a customer with the loan they are asking. This type of NFTs incentivize the customer to repay their debt in time so that they don't lose it. The custom contract that we built acts as an escrow where the user locks in their Stream NFT and Espresso sends money (from their treasury) to the merchant. Then, the customer has to repay back the debt before a predefined deadline and if they don't they can't claim back anymore their NFT, as they are liquidated. 

