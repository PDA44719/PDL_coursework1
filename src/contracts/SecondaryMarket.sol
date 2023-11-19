// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "../interfaces/ISecondaryMarket.sol";
import "../contracts/PurchaseToken.sol";
import "../contracts/TicketNFT.sol";

contract SecondaryMarket is ISecondaryMarket {
    struct ListedTicketInfo {
        address owner;
        uint256 price;
        uint256 maxBid;
        address maxBidder;
        string maxBidderName;
    }
    mapping(address => mapping(uint256 => ListedTicketInfo))
        internal _listedTickets;
    PurchaseToken _purchaseToken;

    modifier OnlyTicketOwner(address ticketCollection, uint256 ticketID) {
        TicketNFT collection = TicketNFT(ticketCollection);
        require(
            msg.sender == collection.holderOf(ticketID) || 
                _listedTickets[ticketCollection][ticketID].owner == msg.sender,
            "Only the ticket owner can call this function"
        );
        _;
    }

    modifier NonExpiredAndUnused(address ticketCollection, uint256 ticketID) {
        TicketNFT collection = TicketNFT(ticketCollection);
        require(
            collection.isExpiredOrUsed(ticketID) == false,
            "The ticket has already expired/been used"
        );
        _;
    }

    modifier TicketIsListed(address ticketCollection, uint256 ticketID) {
        require(
            _listedTickets[ticketCollection][ticketID].owner != address(0),
            "That ticket is not listed"
        );
        _;
    }

    constructor(PurchaseToken purchaseToken) {
        _purchaseToken = purchaseToken;
    }

    function listTicket(
        address ticketCollection,
        uint256 ticketID,
        uint256 price
    )
        external
        OnlyTicketOwner(ticketCollection, ticketID)
        NonExpiredAndUnused(ticketCollection, ticketID)
    {
        // Transfer the ticket to the secondary market
        TicketNFT collection = TicketNFT(ticketCollection);
        collection.transferFrom(msg.sender, address(this), ticketID);

        // Update the _listedTickets internal variable
        _listedTickets[ticketCollection][ticketID].owner = msg.sender;
        _listedTickets[ticketCollection][ticketID].price = price; 
        emit Listing(msg.sender, ticketCollection, ticketID, price);
    }

    function submitBid(
        address ticketCollection,
        uint256 ticketID,
        uint256 bidAmount,
        string calldata name
    )
        external
        TicketIsListed(ticketCollection, ticketID)
        NonExpiredAndUnused(ticketCollection, ticketID)
    {
        require(
            _purchaseToken.allowance(msg.sender, address(this)) == bidAmount,
            "Bid amount was not approved before submitting the bid"
        );
        // If no bids have been made yet
        if (_listedTickets[ticketCollection][ticketID].maxBid == 0) {
            require(
                bidAmount >= _listedTickets[ticketCollection][ticketID].price,
                "The initial bid must be greater than the listing price"
            );
        } else { // If a bid has been made
            require(
                bidAmount > _listedTickets[ticketCollection][ticketID].maxBid,
                "Your bid must be greater than the current max bid"
            );

            // Return the escrowed amount to back the previous max bidder
            _purchaseToken.transfer(
                _listedTickets[ticketCollection][ticketID].maxBidder,
                _listedTickets[ticketCollection][ticketID].maxBid
            );
        }
        
        // Transfer the new max bid to the secondary market 
        _purchaseToken.transferFrom(msg.sender, address(this), bidAmount);

        // Update _listedTickets
        _listedTickets[ticketCollection][ticketID].maxBid = bidAmount;
        _listedTickets[ticketCollection][ticketID].maxBidder = msg.sender;
        _listedTickets[ticketCollection][ticketID].maxBidderName = name;
        emit BidSubmitted(
            msg.sender,
            ticketCollection,
            ticketID,
            bidAmount,
            name
        );
    }

    function getHighestBid(
        address ticketCollection,
        uint256 ticketId
    )
        external
        view
        TicketIsListed(ticketCollection, ticketId)
        returns (uint256)
    {
        uint256 currentMaxBid = _listedTickets[ticketCollection][ticketId].maxBid;
        // Return the max bid amount or the listing price if there are no bids 
        return currentMaxBid > 0 ? currentMaxBid
               : _listedTickets[ticketCollection][ticketId].price;
    }

    function getHighestBidder(
        address ticketCollection,
        uint256 ticketId
    )
        external
        view
        TicketIsListed(ticketCollection, ticketId)
        returns (address)
    {
        return _listedTickets[ticketCollection][ticketId].maxBidder;
    }

    function acceptBid(
        address ticketCollection,
        uint256 ticketID
    )
        external
        OnlyTicketOwner(ticketCollection, ticketID)
        NonExpiredAndUnused(ticketCollection, ticketID)
    {
        require(
            _listedTickets[ticketCollection][ticketID].maxBid != 0,
            "No bids have been made yet"
        );
        
        // Send 95% of the bid amount to the lister
        TicketNFT collection = TicketNFT(ticketCollection);
        _purchaseToken.transfer(
            msg.sender,
            (_listedTickets[ticketCollection][ticketID].maxBid * 95) / 100
        );

        // Send a 5% fee to the creator of the ticket collection
        _purchaseToken.transfer(
            collection.creator(),
            (_listedTickets[ticketCollection][ticketID].maxBid * 5) / 100
        );

        // Update the holder name and send the ticket to the max bidder
        collection.updateHolderName(
            ticketID,
            _listedTickets[ticketCollection][ticketID].maxBidderName
        );
        collection.transferFrom(
            address(this),
            _listedTickets[ticketCollection][ticketID].maxBidder,
            ticketID
        );
        emit BidAccepted(
            _listedTickets[ticketCollection][ticketID].maxBidder,
            ticketCollection,
            ticketID,
            _listedTickets[ticketCollection][ticketID].maxBid,
            _listedTickets[ticketCollection][ticketID].maxBidderName
        );
        delete _listedTickets[ticketCollection][ticketID]; // Delete listing entry
    }

    function delistTicket(
        address ticketCollection,
        uint256 ticketID
    )
        external
        TicketIsListed(ticketCollection, ticketID)
        OnlyTicketOwner(ticketCollection, ticketID)
    {
        // Return the escrowed amount back to the max bidder (if there is one)
        if (_listedTickets[ticketCollection][ticketID].maxBid > 0) {
            _purchaseToken.transfer(
                _listedTickets[ticketCollection][ticketID].maxBidder,
                _listedTickets[ticketCollection][ticketID].maxBid
            );
        }

        // Send the ticket back to the lister and delete the listing entry
        TicketNFT collection = TicketNFT(ticketCollection);
        collection.transferFrom(address(this), msg.sender, ticketID);
        delete _listedTickets[ticketCollection][ticketID];
        emit Delisting(ticketCollection, ticketID);
    }

    /** @notice This method allows the max bidder or the secondary market to return a used
     *  or expired ticket back to the lister, and to return the bid amount to the bidder.
     *  This method is important in cases where a ticket expires or gets used, and the lister
     *  does not choose to delist it.
     */
    function terminateListing(
        address ticketCollection,
        uint256 ticketID
    ) external TicketIsListed(ticketCollection, ticketID) {
        TicketNFT collection = TicketNFT(ticketCollection);
        require( // Can only call this function with expired/used tickets
            collection.isExpiredOrUsed(ticketID) == true,
            "The ticket has not expired/been used"
        );
        require( 
            msg.sender ==
                _listedTickets[ticketCollection][ticketID].maxBidder ||
                msg.sender == address(this),
            "You do not have permission to perform this action"
        );

        // Transfer the ticket back to the lister
        collection.transferFrom(
            address(this),
            _listedTickets[ticketCollection][ticketID].owner,
            ticketID
        );

        // Return the escrowed amount back to the max bidder, if there is one
        if (_listedTickets[ticketCollection][ticketID].maxBidder != address(0)) 
        {
            _purchaseToken.transfer(
                _listedTickets[ticketCollection][ticketID].maxBidder,
                _listedTickets[ticketCollection][ticketID].maxBid
            );
        }
        delete _listedTickets[ticketCollection][ticketID]; // Delete listing entry
    }
}
