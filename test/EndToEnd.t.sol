// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "../src/contracts/PurchaseToken.sol";
import "../src/interfaces/ITicketNFT.sol";
import "../src/interfaces/IPrimaryMarket.sol";
import "../src/contracts/PrimaryMarket.sol";
import "../src/contracts/TicketNFT.sol";
import "../src/contracts/SecondaryMarket.sol";

contract EndToEnd is Test {
    event EventCreated(
        address indexed creator,
        address indexed ticketCollection,
        string eventName,
        uint256 price,
        uint256 maxNumberOfTickets
    );

    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );

    event Purchase(
        address indexed holder,
        address indexed ticketCollection,
        uint256 ticketId,
        string holderName
    );

    event Transfer(address indexed from, address indexed to, uint256 value);

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

    function testCreateNewCollection() public {
        vm.prank(alice);
        /* Check all emit fields except the address of ticketCollection, as
           it is not known until its creation */
        vm.expectEmit(true, false, false, true);
        emit EventCreated(alice, address(0), "sampleEvent", 1e5, 30);
        ITicketNFT ticketCollection = primaryMarket.createNewEvent(
            "sampleEvent",
            1e5, // Ticket price
            30 // Max number of tickets
        );

        assertEq(ticketCollection.creator(), alice);
        assertEq(ticketCollection.eventName(), "sampleEvent");
        assertEq(ticketCollection.maxNumberOfTickets(), 30);
        assertEq(primaryMarket.getPrice(address(ticketCollection)), 1e5);
    }

    function testSuccessfulPurchase() public {
        // Create the collection
        vm.prank(alice);
        ITicketNFT ticketCollection = primaryMarket.createNewEvent(
            "sampleEvent",
            1e5, 
            30
        );

        // Mint 1e5 purchase tokens for bob and execute purchase
        vm.startPrank(bob);
        vm.expectEmit(true, true, false, true);
        emit Transfer(address(0), bob, 1e5);
        purchaseToken.mint{value: 1e3}(); // This value will be x100
        vm.expectEmit(true, true, false, true);
        emit Approval(bob, address(primaryMarket), 1e5);
        purchaseToken.approve(address(primaryMarket), 1e5);
        vm.expectEmit(true, true, false, true);
        emit Purchase(bob, address(ticketCollection), 1, "Robert");
        uint256 id = primaryMarket.purchase(
            address(ticketCollection),
            "Robert"
        );
        vm.stopPrank();

        assertEq(id, 1);
        assertEq(ticketCollection.holderOf(id), bob);
        assertEq(ticketCollection.holderNameOf(id), "Robert");
        assertEq(ticketCollection.balanceOf(bob), 1);
        assertEq(purchaseToken.balanceOf(alice), 1e5);
        assertEq(purchaseToken.balanceOf(bob), 0);
    }

    function testPurchaseWithoutApproval() public {
        // Create the collection
        vm.startPrank(alice);
        ITicketNFT ticketCollection = primaryMarket.createNewEvent(
            "sampleEvent",
            1e5,
            30
        );

        // Attempt to mint ticket without approving the ticket price before
        vm.startPrank(bob);
        purchaseToken.mint{value: 2e18}(); // This value will be x100
        vm.expectRevert("Ticket price was not approved before purchase");
        primaryMarket.purchase(address(ticketCollection), "Robert");
        vm.stopPrank();
    }

    function testPurchaseWithInsufficientFunds() public {
        // Create the collection
        vm.prank(alice);
        ITicketNFT ticketCollection = primaryMarket.createNewEvent(
            "sampleEvent",
            1e5,
            30
        );

        // Attempt to purchase ticket without enough purchase tokens
        vm.startPrank(bob);
        purchaseToken.mint{value: 1e1}(); 
        purchaseToken.approve(address(primaryMarket), 1e5);
        vm.expectRevert("Insufficient funds");
        primaryMarket.purchase(address(ticketCollection), "Robert");
        vm.stopPrank();
    }

    function testPurchaseOfMoreThanMaxTickets() public {
        // Create the collection
        vm.prank(alice);
        ITicketNFT ticketCollection = primaryMarket.createNewEvent(
            "sampleEvent",
            1e5,
            1 // Only one ticket can be purchased
        );
        
        vm.startPrank(bob);
        purchaseToken.mint{value: 2e18}(); 

        // Purchase first ticket
        purchaseToken.approve(address(primaryMarket), 1e5);
        primaryMarket.purchase(address(ticketCollection), "Robert");

        // Attempt to purchase second ticket, despite a max of 1
        purchaseToken.approve(address(primaryMarket), 1e5);
        vm.expectRevert("No more tickets can be minted");
        primaryMarket.purchase(address(ticketCollection), "Robert");
        vm.stopPrank();
    }

    function testNonExistentTicket() public {
        // Create the collection
        vm.prank(alice);
        ITicketNFT ticketCollection = primaryMarket.createNewEvent(
            "sampleEvent",
            1e5,
            30
        );

        /* Attempt to get the holder of ticket number 1 (which does not exist).
           This will test the TicketExists modifier in 'TicketNFT.sol' */
        vm.expectRevert("Invalid ticket ID");
        ticketCollection.holderOf(1);
    }

    function testMintingFromOutsidePrimaryMarket() public {
        // Create the collection
        vm.prank(alice);
        ITicketNFT ticketCollection = primaryMarket.createNewEvent(
            "sampleEvent",
            1e5,
            30
        );

        // Attempt to mint directly from Bob's address
        vm.prank(bob);
        vm.expectRevert("Only the primary Market can mint tickets");
        ticketCollection.mint(bob, "Robert");
    }

    function testTransferTicketWithoutApproval() public {
        // Create the collection and mint one ticket
        vm.prank(alice);
        ITicketNFT ticketCollection = primaryMarket.createNewEvent(
            "sampleEvent",
            1e5,
            30
        );
        vm.startPrank(bob);
        purchaseToken.mint{value: 1e3}(); 
        purchaseToken.approve(address(primaryMarket), 1e5);
        uint256 id = primaryMarket.purchase(
            address(ticketCollection),
            "Robert"
        );
        vm.stopPrank();

        // Attempt to transfer the ticket to Charlie without permission
        vm.prank(charlie);
        vm.expectRevert("Permission error: Ticket could not be transferred");
        ticketCollection.transferFrom(bob, charlie, id);
    }

    function testApproveTransferOfTicketOwnedByThirdParty() public {
        // Create the collection and mint one ticket
        vm.prank(alice);
        ITicketNFT ticketCollection = primaryMarket.createNewEvent(
            "sampleEvent",
            1e5,
            30
        );
        vm.startPrank(bob);
        purchaseToken.mint{value: 1e3}(); 
        purchaseToken.approve(address(primaryMarket), 1e5);
        uint256 id = primaryMarket.purchase(
            address(ticketCollection),
            "Robert"
        );
        vm.stopPrank();

        // Attempt to approve the ticket's transfer from Charlie's address
        vm.prank(charlie);
        vm.expectRevert("You do not own that ticket");
        ticketCollection.approve(charlie, id);
    }
    
    function testZeroAdressTransfer() public {
        // Create the collection and mint one ticket
        vm.prank(alice);
        ITicketNFT ticketCollection = primaryMarket.createNewEvent(
            "sampleEvent",
            1e5,
            30
        );
        vm.startPrank(bob);
        purchaseToken.mint{value: 1e3}(); 
        purchaseToken.approve(address(primaryMarket), 1e5);
        uint256 id = primaryMarket.purchase(
            address(ticketCollection),
            "Robert"
        );

        // Attempt to transfer the ticket to the zero address
        vm.expectRevert("'to' address cannot be the zero address");
        ticketCollection.transferFrom(bob, address(0), id);

        // Attempt to transfer the ticket from the zero address
        vm.expectRevert("'from' address cannot be the zero address");
        ticketCollection.transferFrom(address(0), alice, id);
        vm.stopPrank();
    }

    function testListTicketWithoutApproval() public {
        // Create the collection and mint one ticket
        vm.prank(alice);
        ITicketNFT ticketCollection = primaryMarket.createNewEvent(
            "sampleEvent",
            1e5,
            30
        );
        vm.startPrank(bob);
        purchaseToken.mint{value: 1e3}(); 
        purchaseToken.approve(address(primaryMarket), 1e5);
        uint256 id = primaryMarket.purchase(
            address(ticketCollection),
            "Robert"
        );

        // Attempt to list the ticket without approving its transfer
        vm.expectRevert("Permission error: Ticket could not be transferred");
        secondaryMarket.listTicket(address(ticketCollection), id, 1e7);
        vm.stopPrank();

    }

    function testDelistTicket() public {
        string memory eventName = "sampleEvent";
        uint256 ticketPrice = 1e5;
        uint256 maxTickets = 1;
        ITicketNFT ticketCollection;
        vm.startPrank(charlie);
        ticketCollection = primaryMarket.createNewEvent(
            eventName,
            ticketPrice,
            maxTickets
        );
        vm.stopPrank();
        vm.startPrank(alice);
        purchaseToken.mint{value: 1e18}(); // This value will be x100
        purchaseToken.approve(address(primaryMarket), ticketPrice);
        uint256 id = primaryMarket.purchase(address(ticketCollection), "Alice");
        ticketCollection.approve(address(secondaryMarket), id);
        secondaryMarket.listTicket(address(ticketCollection), id, 1e6);
        assertEq(ticketCollection.holderOf(id), address(secondaryMarket));
        assertEq(ticketCollection.balanceOf(address(secondaryMarket)), 1);
        secondaryMarket.delistTicket(address(ticketCollection), id);
        assertEq(ticketCollection.balanceOf(address(secondaryMarket)), 0);
        vm.stopPrank();
        vm.startPrank(bob);
        purchaseToken.mint{value: 2e18}(); // This value will be x100
        purchaseToken.approve(address(secondaryMarket), 1e6);
        vm.expectRevert("That ticket is not listed");
        secondaryMarket.submitBid(address(ticketCollection), id, 1e6, "Robert");
        assertEq(purchaseToken.balanceOf(address(secondaryMarket)), 0);
        vm.stopPrank();
    }

    //function test

    function testEndToEnd() external {
        uint256 ticketPrice = 20e18;
        uint256 bidPrice = 155e18;

        vm.prank(charlie);
        ITicketNFT ticketNFT = primaryMarket.createNewEvent(
            "Charlie's concert",
            ticketPrice,
            100
        );

        assertEq(ticketNFT.creator(), charlie);
        assertEq(ticketNFT.maxNumberOfTickets(), 100);
        assertEq(primaryMarket.getPrice(address(ticketNFT)), ticketPrice);

        vm.startPrank(alice);
        purchaseToken.mint{value: 1e18}();
        assertEq(purchaseToken.balanceOf(alice), 100e18);
        purchaseToken.approve(address(primaryMarket), 100e18);
        uint256 id = primaryMarket.purchase(address(ticketNFT), "Alice");

        assertEq(ticketNFT.balanceOf(alice), 1);
        assertEq(ticketNFT.holderOf(id), alice);
        assertEq(ticketNFT.holderNameOf(id), "Alice");
        assertEq(purchaseToken.balanceOf(alice), 100e18 - ticketPrice);
        assertEq(purchaseToken.balanceOf(charlie), ticketPrice);

        ticketNFT.approve(address(secondaryMarket), id);
        secondaryMarket.listTicket(address(ticketNFT), id, 150e18);

        assertEq(secondaryMarket.getHighestBid(address(ticketNFT), id), 150e18);
        assertEq(
            secondaryMarket.getHighestBidder(address(ticketNFT), id),
            address(0)
        );

        vm.stopPrank();
        vm.startPrank(bob);
        purchaseToken.mint{value: 2e18}();
        purchaseToken.approve(address(secondaryMarket), bidPrice);
        secondaryMarket.submitBid(address(ticketNFT), id, bidPrice, "Bob");

        assertEq(
            secondaryMarket.getHighestBid(address(ticketNFT), id),
            bidPrice
        );
        assertEq(secondaryMarket.getHighestBidder(address(ticketNFT), id), bob);

        assertEq(ticketNFT.balanceOf(alice), 0);
        assertEq(ticketNFT.balanceOf(address(secondaryMarket)), 1);
        assertEq(purchaseToken.balanceOf(address(secondaryMarket)), bidPrice);
        assertEq(ticketNFT.holderOf(id), address(secondaryMarket));
        assertEq(ticketNFT.holderNameOf(id), "Alice");

        vm.stopPrank();

        uint256 aliceBalanceBefore = purchaseToken.balanceOf(alice);

        vm.prank(alice);
        secondaryMarket.acceptBid(address(ticketNFT), id);
        assertEq(purchaseToken.balanceOf(address(secondaryMarket)), 0);
        uint256 fee = (bidPrice * 0.05e18) / 1e18;
        assertEq(purchaseToken.balanceOf(charlie), ticketPrice + fee);
        assertEq(
            purchaseToken.balanceOf(alice),
            aliceBalanceBefore + bidPrice - fee
        );
        assertEq(ticketNFT.holderOf(id), bob);
        assertEq(ticketNFT.holderNameOf(id), "Bob");
    }
}
