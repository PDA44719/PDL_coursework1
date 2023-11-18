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

    function _createCollectionAndMintOneTicket() private returns(ITicketNFT) {
        vm.prank(alice);
        ITicketNFT ticketCollection = primaryMarket.createNewEvent(
            "sampleEvent",
            1e5,
            30
        );
        vm.startPrank(bob);
        purchaseToken.mint{value: 1e3}(); 
        purchaseToken.approve(address(primaryMarket), 1e5);
        primaryMarket.purchase(
            address(ticketCollection),
            "Robert"
        );
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
}