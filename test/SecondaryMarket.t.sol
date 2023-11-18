// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "../src/contracts/PurchaseToken.sol";
import "../src/interfaces/ITicketNFT.sol";
import "../src/interfaces/IPrimaryMarket.sol";
import "../src/contracts/PrimaryMarket.sol";
import "../src/contracts/TicketNFT.sol";
import "../src/contracts/SecondaryMarket.sol";

contract SecondaryMarketTest is Test {
    event Delisting(address indexed ticketCollection, uint256 indexed ticketID);

    event Log(uint256 amount);
    event Print(string check);

    PrimaryMarket public primaryMarket;
    PurchaseToken public purchaseToken;
    SecondaryMarket public secondaryMarket;

    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public charlie = makeAddr("charlie");

    function setUp() public {
        purchaseToken = new PurchaseToken();
        primaryMarket = new PrimaryMarket(purchaseToken);
        secondaryMarket = new SecondaryMarket(purchaseToken);

        payable(alice).transfer(1e18);
        payable(bob).transfer(2e18);
    }

    function _createCollectionAndMintOneTicket() private returns(ITicketNFT) {
        vm.prank(alice);
        ITicketNFT ticketCollection = primaryMarket.createNewEvent(
            "sampleEvent",
            1e5,
            30
        );
        vm.startPrank(bob);
        purchaseToken.mint{value: 1e10}(); 
        purchaseToken.approve(address(primaryMarket), 1e5);
        primaryMarket.purchase(
            address(ticketCollection),
            "Robert"
        );
        vm.stopPrank();
        return ticketCollection;
    }

    function _listTicketAfterCreation() private returns(ITicketNFT) {
        ITicketNFT ticketCollection = _createCollectionAndMintOneTicket();
        vm.startPrank(bob);
        ticketCollection.approve(address(secondaryMarket), 1);
        secondaryMarket.listTicket(address(ticketCollection), 1, 1e7);
        vm.stopPrank();
        return ticketCollection;
    }

    function testListTicketWithoutApproval() public {
        ITicketNFT ticketCollection = _createCollectionAndMintOneTicket();
        // Attempt to list the ticket without approving its transfer
        vm.prank(bob);
        vm.expectRevert("Permission error: Ticket could not be transferred");
        secondaryMarket.listTicket(address(ticketCollection), 1, 1e7);
    }

    /* This test checks that the OnlyTicketOwner modifier is working properly.
       There is no need to repeat this test for other functions using that modifier
    */
    function testListTicketWithoutBeingTheOwner() public {
        ITicketNFT ticketCollection = _createCollectionAndMintOneTicket();
        // Attempt to list the ticket from Alice's address (not the owner)
        vm.prank(alice);
        vm.expectRevert("Only the ticket owner can call this function");
        secondaryMarket.listTicket(address(ticketCollection), 1, 1e7);
    }

    /* This test and the following check that the NonExpiredAndUnused modifier is working
       properly. There is no need to repeat them for other functions using that modifier
    */
    function testListExpiredTicket() public {
        ITicketNFT ticketCollection = _createCollectionAndMintOneTicket();
        skip(864000); // Skip forward block.timestamp until the ticket is expired
        vm.startPrank(bob);
        ticketCollection.approve(address(secondaryMarket), 1);
        vm.expectRevert("The ticket has already expired/been used");
        secondaryMarket.listTicket(address(ticketCollection), 1, 1e7);
        vm.stopPrank();
    }

    function testListUsedTicket() public {
        ITicketNFT ticketCollection = _createCollectionAndMintOneTicket();
        vm.prank(alice);
        ticketCollection.setUsed(1); // Collection creator set the ticket to used
        vm.startPrank(bob);
        ticketCollection.approve(address(secondaryMarket), 1);
        vm.expectRevert("The ticket has already expired/been used");
        secondaryMarket.listTicket(address(ticketCollection), 1, 1e7);
        vm.stopPrank();
    }

    function testSubmitBidWithoutApproval() public {
        ITicketNFT ticketCollection = _listTicketAfterCreation();
        vm.startPrank(alice);
        purchaseToken.mint{value: 1e10}(); 
        vm.expectRevert("Bid amount was not approved before submitting the bid");
        secondaryMarket.submitBid(address(ticketCollection), 1, 1e8, "Alice");
        vm.stopPrank();
    }

    function testSubmitBidForUnlistedTicket() public {
        ITicketNFT ticketCollection = _createCollectionAndMintOneTicket();
        // Submit bid for ticket 1 (not listed)
        vm.startPrank(alice);
        purchaseToken.mint{value: 1e10}(); 
        purchaseToken.approve(address(secondaryMarket), 1e7); 
        vm.expectRevert("That ticket is not listed");
        secondaryMarket.submitBid(address(ticketCollection), 1, 1e7, "Alice");
        vm.stopPrank();
    }

    function testSubmitBidThatIsBellowPrice() public {
        ITicketNFT ticketCollection = _listTicketAfterCreation();
        // Submit bid that is bellow the listed price (which is 1e7)
        vm.startPrank(alice);
        purchaseToken.mint{value: 1e10}(); 
        purchaseToken.approve(address(secondaryMarket), 1e5); 
        vm.expectRevert("The initial bid must be greater than the listing price");
        secondaryMarket.submitBid(address(ticketCollection), 1, 1e5, "Alice");
        vm.stopPrank();
    }

    function testSubmitBidThatIsBellowPreviousMaxBid() public {
        ITicketNFT ticketCollection = _listTicketAfterCreation();
        // Submit the first bid
        vm.startPrank(alice);
        purchaseToken.mint{value: 1e10}(); 
        purchaseToken.approve(address(secondaryMarket), 1e9); 
        secondaryMarket.submitBid(address(ticketCollection), 1, 1e9, "Alice"); 
        vm.stopPrank();

        // Submit the second bid: this time lower than the first bid
        vm.startPrank(bob);
        purchaseToken.approve(address(secondaryMarket), 1e8); 
        vm.expectRevert("Your bid must be greater than the current max bid");
        secondaryMarket.submitBid(address(ticketCollection), 1, 1e8, "Robert"); 
        vm.stopPrank();
    }

    function testAcceptBidWhenNonHaveBeenMade() public {
        ITicketNFT ticketCollection = _listTicketAfterCreation();
        vm.prank(bob);
        vm.expectRevert("No bids have been made yet");
        secondaryMarket.acceptBid(address(ticketCollection), 1);
    }

    function testSuccessfulTicketDelisting() public {
        ITicketNFT ticketCollection = _listTicketAfterCreation();
        //assertEq(ticketCollection.holderOf(id), address(secondaryMarket));
        //assertEq(ticketCollection.balanceOf(address(secondaryMarket)), 1);
        // Delist the ticket
        vm.startPrank(bob);
        vm.expectEmit(true, true, false, false);
        emit Delisting(address(ticketCollection), 1);
        secondaryMarket.delistTicket(address(ticketCollection), 1);
        assertEq(ticketCollection.balanceOf(address(secondaryMarket)), 0);
        vm.stopPrank();
        
        // Attempt to submit a bid for the delisted ticket
        vm.startPrank(alice);
        purchaseToken.mint{value: 1e12}(); 
        purchaseToken.approve(address(secondaryMarket), 1e8);
        vm.expectRevert("That ticket is not listed");
        secondaryMarket.submitBid(address(ticketCollection), 1, 1e8, "Alice");
        vm.stopPrank();
    }

    function testEscrowAmountAfterTicketIsExpiredOrUsed() public {
        ITicketNFT ticketCollection = _listTicketAfterCreation();
        // Submit a bid for the ticket
        vm.startPrank(alice);
        purchaseToken.mint{value: 1e12}(); 
        purchaseToken.approve(address(secondaryMarket), 1e8);
        secondaryMarket.submitBid(address(ticketCollection), 1, 1e8, "Alice");
        assertEq(purchaseToken.balanceOf(address(secondaryMarket)), 1e8);

        skip(864000); // Skip forward block.timestamp until the ticket is expired
        secondaryMarket.returnEscrowAmount(address(ticketCollection), 1);
        vm.stopPrank();

        
    }
}