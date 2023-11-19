// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "../src/contracts/PurchaseToken.sol";
import "../src/interfaces/ITicketNFT.sol";
import "../src/contracts/PrimaryMarket.sol";
import "../src/contracts/SecondaryMarket.sol";

contract SecondaryMarketTest is Test {
    event Listing(
        address indexed holder,
        address indexed ticketCollection,
        uint256 indexed ticketID,
        uint256 price
    );

    event BidSubmitted(
        address indexed bidder,
        address indexed ticketCollection,
        uint256 indexed ticketID,
        uint256 bidAmount,
        string newName
    );

    event BidAccepted(
        address indexed bidder,
        address indexed ticketCollection,
        uint256 indexed ticketID,
        uint256 bidAmount,
        string newName
    );

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
        payable(bob).transfer(1e18);
        payable(charlie).transfer(1e18);
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

    function testSuccessfulListTicket() public {
        ITicketNFT ticketCollection = _createCollectionAndMintOneTicket();
        vm.startPrank(bob);
        ticketCollection.approve(address(secondaryMarket), 1);
        vm.expectEmit(true, true, true, true);
        emit Listing(bob, address(ticketCollection), 1, 1e7);
        secondaryMarket.listTicket(address(ticketCollection), 1, 1e7);
        vm.stopPrank();

        assertEq(ticketCollection.balanceOf(bob), 0);
        assertEq(ticketCollection.balanceOf(address(secondaryMarket)), 1);
        assertEq(ticketCollection.holderOf(1), address(secondaryMarket));
        assertEq(secondaryMarket.getHighestBid(address(ticketCollection), 1), 1e7);
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

    function testSuccessfulSubmitBid() public {
        ITicketNFT ticketCollection = _listTicketAfterCreation();
        vm.startPrank(charlie);
        purchaseToken.mint{value: 1e7}(); // This value will be x100
        purchaseToken.approve(address(secondaryMarket), 1e9); 
        vm.expectEmit(true, true, true, true);
        emit BidSubmitted(charlie, address(ticketCollection), 1, 1e9, "Charles");
        secondaryMarket.submitBid(address(ticketCollection), 1, 1e9, "Charles");
        vm.stopPrank();

        assertEq(secondaryMarket.getHighestBid(address(ticketCollection), 1), 1e9);
        assertEq(secondaryMarket.getHighestBidder(address(ticketCollection), 1), charlie);
        assertEq(purchaseToken.balanceOf(charlie), 0);
        assertEq(purchaseToken.balanceOf(address(secondaryMarket)), 1e9);
    }

    function testSubmitBidWithoutApproval() public {
        ITicketNFT ticketCollection = _listTicketAfterCreation();
        vm.startPrank(alice);
        purchaseToken.mint{value: 1e10}(); 
        vm.expectRevert("Bid amount was not approved before submitting the bid");
        secondaryMarket.submitBid(address(ticketCollection), 1, 1e8, "Alice");
        vm.stopPrank();
    }

    /* This test checks that the NonExpiredAndUnused modifier is working properly.
       There is no need to repeat this test for other functions using that modifier
    */
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

    function testSuccessfulAcceptBid() public {
        ITicketNFT ticketCollection = _listTicketAfterCreation();
        uint256 previousBobTokens = purchaseToken.balanceOf(bob);
        
        // Submit a bid for ticket 1
        vm.startPrank(charlie);
        purchaseToken.mint{value: 1e7}();  // This amount will be x100
        purchaseToken.approve(address(secondaryMarket), 1e9); 
        secondaryMarket.submitBid(address(ticketCollection), 1, 1e9, "Charles");
        vm.stopPrank();

        // Accept the bid
        vm.prank(bob);
        vm.expectEmit(true, true, true, true);
        emit BidAccepted(charlie, address(ticketCollection), 1, 1e9, "Charles");
        secondaryMarket.acceptBid(address(ticketCollection), 1);

        assertEq(ticketCollection.holderOf(1), charlie);
        assertEq(ticketCollection.balanceOf(bob), 0);
        assertEq(ticketCollection.holderNameOf(1), "Charles");
        // Make sure that bob has received the bid amount (minus the 5% fee)
        assertEq(purchaseToken.balanceOf(bob), previousBobTokens  + 1e9*95/100);
        assertEq(purchaseToken.balanceOf(charlie), 0); 
    }

    function testAcceptBidWhenNonHaveBeenMade() public {
        ITicketNFT ticketCollection = _listTicketAfterCreation();
        vm.prank(bob);
        vm.expectRevert("No bids have been made yet");
        secondaryMarket.acceptBid(address(ticketCollection), 1);
    }

    function testSuccessfulTicketDelisting() public {
        ITicketNFT ticketCollection = _listTicketAfterCreation();
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

    function testSuccessfulTerminateListing() public {
        ITicketNFT ticketCollection = _listTicketAfterCreation();
        // Submit a bid for the ticket
        vm.startPrank(charlie);
        purchaseToken.mint{value: 1e6}(); // This amount will be x100
        purchaseToken.approve(address(secondaryMarket), 1e8);
        secondaryMarket.submitBid(address(ticketCollection), 1, 1e8, "Charles");
        assertEq(ticketCollection.balanceOf(address(secondaryMarket)), 1);
        assertEq(purchaseToken.balanceOf(address(secondaryMarket)), 1e8);
        assertEq(purchaseToken.balanceOf(charlie), 0);
        vm.stopPrank();

        // Force the ticket to expire and call the terminate listing function
        skip(864000); 
        vm.prank(address(secondaryMarket));
        secondaryMarket.terminateListing(address(ticketCollection), 1);

        // Ensure the ticket was returned to the owner and the bid amount to charlie
        assertEq(ticketCollection.balanceOf(address(secondaryMarket)), 0);
        assertEq(ticketCollection.balanceOf(bob), 1);
        assertEq(purchaseToken.balanceOf(address(secondaryMarket)), 0);
        assertEq(purchaseToken.balanceOf(charlie), 1e8);
    }

    function testTerminateListingFromAccountWithoutPermission() public {
        ITicketNFT ticketCollection = _listTicketAfterCreation();
        skip(864000); 
        vm.prank(alice); // Not the max bidder nor the secondary market
        vm.expectRevert("You do not have permission to perform this action");
        secondaryMarket.terminateListing(address(ticketCollection), 1);
    }

    function testTerminateNonExpiredListing() public {
        ITicketNFT ticketCollection = _listTicketAfterCreation();
        // Submit a bid for the ticket
        vm.startPrank(charlie);
        purchaseToken.mint{value: 1e6}(); 
        purchaseToken.approve(address(secondaryMarket), 1e8);
        secondaryMarket.submitBid(address(ticketCollection), 1, 1e8, "Charles");

        // Try to retrieve the escrowed amount while the ticket has not expired/been used
        vm.expectRevert("The ticket has not expired/been used");
        secondaryMarket.terminateListing(address(ticketCollection), 1);
        vm.stopPrank();
    }
}