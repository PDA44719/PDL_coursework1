// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "../src/contracts/PurchaseToken.sol";
import "../src/interfaces/ITicketNFT.sol";
import "../src/contracts/PrimaryMarket.sol";
import "../src/contracts/SecondaryMarket.sol";

contract PrimaryMarketTest is Test {
    event EventCreated(
        address indexed creator,
        address indexed ticketCollection,
        string eventName,
        uint256 price,
        uint256 maxNumberOfTickets
    );

    event Purchase(
        address indexed holder,
        address indexed ticketCollection,
        uint256 ticketId,
        string holderName
    );

    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );

    event Transfer(address indexed from, address indexed to, uint256 value);

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
        /* Check all emit fields except the address of collection, as
           it is not known until its creation
        */
        vm.expectEmit(true, false, false, true);
        emit EventCreated(alice, address(0), "sampleEvent", 1e5, 30);
        ITicketNFT collection = primaryMarket.createNewEvent(
            "sampleEvent",
            1e5, // Ticket price
            30 // Max number of tickets
        );

        assertEq(collection.creator(), alice);
        assertEq(collection.eventName(), "sampleEvent");
        assertEq(collection.maxNumberOfTickets(), 30);
        assertEq(primaryMarket.getPrice(address(collection)), 1e5);
    }

    function testSuccessfulPurchase() public {
        // Create the collection
        vm.prank(alice);
        ITicketNFT collection = primaryMarket.createNewEvent(
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
        emit Purchase(bob, address(collection), 1, "Robert");
        uint256 id = primaryMarket.purchase(
            address(collection),
            "Robert"
        );
        vm.stopPrank();

        assertEq(id, 1);
        assertEq(collection.holderOf(id), bob);
        assertEq(collection.holderNameOf(id), "Robert");
        assertEq(collection.balanceOf(bob), 1);
        assertEq(purchaseToken.balanceOf(alice), 1e5);
        assertEq(purchaseToken.balanceOf(bob), 0);
    }

    function testPurchaseWithoutApproval() public {
        // Create the collection
        vm.startPrank(alice);
        ITicketNFT collection = primaryMarket.createNewEvent(
            "sampleEvent",
            1e5,
            30
        );

        // Attempt to mint ticket without approving the ticket price before
        vm.startPrank(bob);
        purchaseToken.mint{value: 2e18}(); // This value will be x100
        vm.expectRevert("Ticket price was not approved before purchase");
        primaryMarket.purchase(address(collection), "Robert");
        vm.stopPrank();
    }

    function testPurchaseWithInsufficientFunds() public {
        // Create the collection
        vm.prank(alice);
        ITicketNFT collection = primaryMarket.createNewEvent(
            "sampleEvent",
            1e5,
            30
        );

        // Attempt to purchase ticket without enough purchase tokens
        vm.startPrank(bob);
        purchaseToken.mint{value: 1e1}(); 
        purchaseToken.approve(address(primaryMarket), 1e5);
        vm.expectRevert("Insufficient funds");
        primaryMarket.purchase(address(collection), "Robert");
        vm.stopPrank();
    }

    function testPurchaseOfMoreThanMaxTickets() public {
        // Create the collection
        vm.prank(alice);
        ITicketNFT collection = primaryMarket.createNewEvent(
            "sampleEvent",
            1e5,
            1 // Only one ticket can be purchased
        );
        
        vm.startPrank(bob);
        purchaseToken.mint{value: 2e18}(); 

        // Purchase first ticket
        purchaseToken.approve(address(primaryMarket), 1e5);
        primaryMarket.purchase(address(collection), "Robert");

        // Attempt to purchase second ticket, despite a max of 1
        purchaseToken.approve(address(primaryMarket), 1e5);
        vm.expectRevert("No more tickets can be minted");
        primaryMarket.purchase(address(collection), "Robert");
        vm.stopPrank();
    }
}