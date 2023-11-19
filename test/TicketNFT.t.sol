// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "../src/contracts/PurchaseToken.sol";
import "../src/interfaces/ITicketNFT.sol";
import "../src/contracts/PrimaryMarket.sol";
import "../src/contracts/SecondaryMarket.sol";

contract TicketNFTTest is Test {
    event Approval(
        address indexed holder,
        address indexed approved,
        uint256 indexed ticketID
    );

    event Transfer(
        address indexed from,
        address indexed to,
        uint256 indexed ticketID
    );

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

    function testSuccesfulTicketTransfer() public {
        ITicketNFT ticketCollection = _createCollectionAndMintOneTicket();

        // Approve Charlie to be able to transfer ticket 1
        vm.prank(bob);
        vm.expectEmit(true, true, true, false);
        emit Approval(bob, charlie, 1);
        ticketCollection.approve(charlie, 1);

        // Transfer ticket to Charlie
        vm.startPrank(charlie);
        vm.expectEmit(true, true, true, false);
        emit Transfer(bob, charlie, 1);
        vm.expectEmit(true, true, true, false);
        emit Approval(charlie, address(0), 1);
        ticketCollection.transferFrom(bob, charlie, 1);
        ticketCollection.updateHolderName(1, "Charles");

        assertEq(ticketCollection.balanceOf(charlie), 1);
        assertEq(ticketCollection.balanceOf(bob), 0);
        assertEq(ticketCollection.holderOf(1), charlie);
        assertEq(ticketCollection.holderNameOf(1), "Charles");
        assertEq(ticketCollection.getApproved(1), address(0)); 
    }

    function testTransferTicketWithoutApproval() public {
        ITicketNFT ticketCollection = _createCollectionAndMintOneTicket();

        // Attempt to transfer the ticket to Charlie without permission
        vm.prank(charlie);
        vm.expectRevert("Permission error: Ticket could not be transferred");
        ticketCollection.transferFrom(bob, charlie, 1);
    }

    function testApproveTransferOfTicketOwnedByThirdParty() public {
        ITicketNFT ticketCollection = _createCollectionAndMintOneTicket();

        // Attempt to approve the ticket's transfer from Charlie's address
        vm.prank(charlie);
        vm.expectRevert("You do not own that ticket");
        ticketCollection.approve(charlie, 1);
    }
    
    function testZeroAdressTransfer() public {
        ITicketNFT ticketCollection = _createCollectionAndMintOneTicket();

        // Attempt to transfer the ticket to the zero address
        vm.startPrank(bob);
        vm.expectRevert("'to' address cannot be the zero address");
        ticketCollection.transferFrom(bob, address(0), 1);

        // Attempt to transfer the ticket from the zero address
        vm.expectRevert("'from' address cannot be the zero address");
        ticketCollection.transferFrom(address(0), alice, 1);
        vm.stopPrank();
    }

    function testUpdateHolderName() public {
        ITicketNFT ticketCollection = _createCollectionAndMintOneTicket();
        vm.prank(bob);
        ticketCollection.updateHolderName(1, "Bobby");
        assertEq(ticketCollection.holderNameOf(1), "Bobby");
    }

    function testUpdateHolderNameFromNonHolderAddress() public {
        ITicketNFT ticketCollection = _createCollectionAndMintOneTicket();
        // Attempt to update the holder's name from Charlie's address
        vm.prank(charlie);
        vm.expectRevert("Only the ticket holder can update the name");
        ticketCollection.updateHolderName(1, "Charlie");
    }

    function testSetUsedTicket() public {
        ITicketNFT ticketCollection = _createCollectionAndMintOneTicket();
        vm.prank(alice);
        ticketCollection.setUsed(1);
        assertEq(ticketCollection.isExpiredOrUsed(1), true);
    }

    function testExpiredTicket() public {
        ITicketNFT ticketCollection = _createCollectionAndMintOneTicket();
        skip(864000); // Skip forward block.timestamp until the ticket is expired
        assertEq(ticketCollection.isExpiredOrUsed(1), true);
    }
    
    function testSetUsedTicketFromNonCreatorsAccount() public {
        ITicketNFT ticketCollection = _createCollectionAndMintOneTicket();
        // Attempt to set the ticket to used from Bob's address
        vm.prank(bob);
        vm.expectRevert("Only the collection creator can call this function");
        ticketCollection.setUsed(1);
    }

    function testSetUsedTicketTwice() public {
        ITicketNFT ticketCollection = _createCollectionAndMintOneTicket();
        vm.startPrank(alice);
        ticketCollection.setUsed(1);
        vm.expectRevert("The ticket had already been used");
        ticketCollection.setUsed(1);
        vm.stopPrank();
    }

    function testSetUsedTicketAfterExpired() public {
        ITicketNFT ticketCollection = _createCollectionAndMintOneTicket();
        // Attempt to set the ticket to used after it has expired
        skip(864000); // Skip forward block.timestamp until the ticket is expired
        vm.prank(alice);
        vm.expectRevert("The ticket has already expired");
        ticketCollection.setUsed(1);
    }
}