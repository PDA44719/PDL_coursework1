# Principles of Distributed Ledgers Coursework

This is the repository for the coursework of the Principle of Distributed Ledgers 2023 module.
It uses [Foundry](https://book.getfoundry.sh/projects/working-on-an-existing-project).

## Structure
The repository contains [the interfaces](./src/interfaces) of the contracts to implement and an [ERC20 implementation](./src/contracts/PurchaseToken.sol).

The contracts that were created are: [TicketNFT.sol](./src/contracts/TicketNFT.sol), [PrimaryMarket.sol](./src/contracts/PrimaryMarket.sol) and [SecondaryMarket.sol](./src/contracts/SecondaryMarket.sol).
In order to test those contracts, three new files were generated. These can be found in the [test directory](./test).

The two main goal of each of the test files are:
- To test the successful implementation of the different functionalities of the contracts. 
- To ensure that error handling works as intended.

There are a total of 35 tests. In order to run the tests, it is recommended that they are run separately, as it will provide a clearer overview of the different functionalities being tested for each smart contract.

The command to run the tests is: 
```forge test --mc [NameOfTheTest] -vvv```. The 4 tests that can be run are: ```TicketNFTTest```, ```PrimaryMarketTest```, ```SecondaryMarketTest``` and ```EndToEnd```. 

## Additional Functionality
As somebody mentioned in Scientia, there was a potential problem in the Seconday Market: If a listed ticket expires and the lister does not call ```delistTicket```, then the max bid amount (which is held in by the Seconday Market) cannot be retrieved by the bidder.

In order to fix this issue, a ```terminateListing``` method was created. This function can be called either by the Seconday Market or by the max bidder, and will ensure that the bid amount gets returned to the bidder **if the listed ticket has expired or been used**.