// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "../src/contracts/PurchaseToken.sol";
import "../src/interfaces/ITicketNFT.sol";
import "../src/interfaces/IPrimaryMarket.sol";
import "../src/contracts/PrimaryMarket.sol";
import "../src/contracts/TicketNFT.sol";
//import "../src/contracts/SecondaryMarket.sol";

contract EndToEnd is Test {
    event EventCreated(
        address indexed creator,
        address indexed ticketCollection,
        string eventName,
        uint256 price,
        uint256 maxNumberOfTickets
    );

    PrimaryMarket public primaryMarket;
    PurchaseToken public purchaseToken;
    //SecondaryMarket public secondaryMarket;

    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public charlie = makeAddr("charlie");

    function setUp() public {
        purchaseToken = new PurchaseToken();
        primaryMarket = new PrimaryMarket(purchaseToken);
        //secondaryMarket = new SecondaryMarket(purchaseToken);

        payable(alice).transfer(1e18);
        payable(bob).transfer(2e18);
    }

	function testCreateNewCollection() public {
		string memory eventName = "sampleEvent";
		uint256 ticketPrice = 20;
		uint256 maxTickets = 30;
		TicketNFT ticketCollection;
		vm.prank(alice);
		// address of collection not checked as it was not created yet
		vm.expectEmit(true, false, false, true); 
		emit EventCreated(alice, address(ticketCollection), eventName, ticketPrice, maxTickets);
		ticketCollection = primaryMarket.createNewEvent(
			eventName, ticketPrice, maxTickets
		);

		assertEq(ticketCollection.creator(), alice);
		assertEq(ticketCollection.eventName(), "sampleEvent");
		assertEq(ticketCollection.maxNumberOfTickets(), 30);
		assertEq(primaryMarket.getPrice(address(ticketCollection)), 20);
	}

    function testPurchase() public{
		string memory eventName = "sampleEvent";
		uint256 ticketPrice = 1e18;
		uint256 maxTickets = 30;
		TicketNFT ticketCollection;
		vm.prank(alice);
		ticketCollection = primaryMarket.createNewEvent(
			eventName, ticketPrice, maxTickets
		);
        vm.prank(bob);
        uint256 id = primaryMarket.purchase(address(ticketCollection), "Robert");

        assertEq(id, 1);
		assertEq(ticketCollection.holderOf(id), bob);
		assertEq(ticketCollection.holderNameOf(id), "Robert");
        
    }
	//function test

	/*
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
	*/
}
