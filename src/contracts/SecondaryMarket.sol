
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "../interfaces/ISecondaryMarket.sol";
import "../contracts/PurchaseToken.sol";
import "../contracts/TicketNFT.sol";

contract SecondaryMarket is ISecondaryMarket { 
    event Log(string message);
    struct ListedTicketInfo {
        address owner;
        uint256 price;
        uint256 maxBid;
        address maxBidder;
        string maxBidderName;
    }

    mapping(address => mapping(uint256 => ListedTicketInfo)) internal _listedTickets;
	PurchaseToken _purchaseToken;

    modifier OnlyTicketOwner(address ticketCollection, uint256 ticketID) {
        TicketNFT collection = TicketNFT(ticketCollection);
        require(
            msg.sender == collection.holderOf(ticketID) ||  // User is the owner
            _listedTickets[ticketCollection][ticketID].owner == msg.sender,
            "Only the ticket owner can call this function"
        );
        _;
    }

    modifier NonExpiredAndUnused(address ticketCollection, uint256 ticketID) {
        TicketNFT collection = TicketNFT(ticketCollection);
        require(collection.isExpiredOrUsed(ticketID) == false, "The ticket has already expired/been used");
        _;
    }

	constructor(PurchaseToken purchaseToken){
		_purchaseToken = purchaseToken;
	}

    /**
     * @dev This method lists a ticket with `ticketID` for sale by transferring the ticket
     * such that it is held by this contract. Only the current owner of a specific
     * ticket is able to list that ticket on the secondary market. The purchase
     * `price` is specified in an amount of `PurchaseToken`.
     * Note: Only non-expired and unused tickets can be listed
     */
    function listTicket(address ticketCollection, uint256 ticketID, uint256 price
    ) OnlyTicketOwner(ticketCollection, ticketID) NonExpiredAndUnused(ticketCollection, ticketID)
    external{
        TicketNFT collection = TicketNFT(ticketCollection);
        collection.transferFrom(msg.sender, address(this), ticketID);
        emit Listing(msg.sender, ticketCollection, ticketID, price);
        _listedTickets[ticketCollection][ticketID].owner = msg.sender;
        _listedTickets[ticketCollection][ticketID].price = price; // I have not 
    }

    /** @notice This method allows the msg.sender to submit a bid for the ticket from `ticketCollection` with `ticketID`
     * The `bidAmount` should be kept in escrow by the contract until the bid is accepted, a higher bid is made,
     * or the ticket is delisted.
     * If this is not the first bid for this ticket, `bidAmount` must be strictly higher that the previous bid.
     * `name` gives the new name that should be stated on the ticket when it is purchased.
     * Note: Bid can only be made on non-expired and unused tickets
     */
    function submitBid(
        address ticketCollection,
        uint256 ticketID,
        uint256 bidAmount,
        string calldata name
    ) NonExpiredAndUnused(ticketCollection, ticketID) external{
        require(_purchaseToken.allowance(msg.sender, address(this)) == bidAmount, "Bid amount was not approved before submitting the bid");
        require(_listedTickets[ticketCollection][ticketID].owner != address(0), "That ticket is not listed");
        if (_listedTickets[ticketCollection][ticketID].maxBid == 0){  // No bid has been made yet
            require(bidAmount >= _listedTickets[ticketCollection][ticketID].price, "The initial bid must be greater than the listing price");
        } else {
            require(bidAmount > _listedTickets[ticketCollection][ticketID].maxBid, "Your bid must be greater than the current max bid");

            // return the escrowed amount to back the previous max bidder
            _purchaseToken.transfer(_listedTickets[ticketCollection][ticketID].maxBidder, _listedTickets[ticketCollection][ticketID].maxBid);
        }
        //TicketNFT collection = TicketNFT(ticketCollection);
        _purchaseToken.transferFrom(msg.sender, address(this), bidAmount);
        _listedTickets[ticketCollection][ticketID].maxBid = bidAmount;
        _listedTickets[ticketCollection][ticketID].maxBidder = msg.sender;
        _listedTickets[ticketCollection][ticketID].maxBidderName = name;
        emit BidSubmitted(msg.sender, ticketCollection, ticketID, bidAmount, name);
    }

    /**
     * Returns the current highest bid for the ticket from `ticketCollection` with `ticketID`
     */
    function getHighestBid(
        address ticketCollection,
        uint256 ticketId
    ) external view returns (uint256){
        uint256 currentMaxBid = _listedTickets[ticketCollection][ticketId].maxBid;
        return currentMaxBid > 0 ? currentMaxBid : _listedTickets[ticketCollection][ticketId].price;
    }

    /**
     * Returns the current highest bidder for the ticket from `ticketCollection` with `ticketID`
     */
    function getHighestBidder(
        address ticketCollection,
        uint256 ticketId
    ) external view returns (address){
        return _listedTickets[ticketCollection][ticketId].maxBidder;
    }

    /*
     * @notice Allow the lister of the ticket from `ticketCollection` with `ticketID` to accept the current highest bid.
     * This function reverts if there is currently no bid.
     * Otherwise, it should accept the highest bid, transfer the money to the lister of the ticket,
     * and transfer the ticket to the highest bidder after having set the ticket holder name appropriately.
     * A fee charged when the bid is accepted. The fee is charged on the bid amount.
     * The final amount that the lister of the ticket receives is the price
     * minus the fee. The fee should go to the creator of the `ticketCollection`.
     */
    function acceptBid(
        address ticketCollection,
        uint256 ticketID
    ) OnlyTicketOwner(ticketCollection, ticketID) NonExpiredAndUnused(ticketCollection, ticketID) external{
        require(_listedTickets[ticketCollection][ticketID].maxBid != 0, "No bids have been made yet");
        TicketNFT collection = TicketNFT(ticketCollection);
        emit BidAccepted(
            _listedTickets[ticketCollection][ticketID].maxBidder,
            ticketCollection, ticketID,
            _listedTickets[ticketCollection][ticketID].maxBid,
            _listedTickets[ticketCollection][ticketID].maxBidderName);
        _purchaseToken.transfer(msg.sender, _listedTickets[ticketCollection][ticketID].maxBid * 95 / 100);
        _purchaseToken.transfer(collection.creator(), _listedTickets[ticketCollection][ticketID].maxBid * 5 / 100);
        collection.updateHolderName(ticketID, _listedTickets[ticketCollection][ticketID].maxBidderName);
        collection.transferFrom(address(this), _listedTickets[ticketCollection][ticketID].maxBidder, ticketID);
        delete _listedTickets[ticketCollection][ticketID];
    }

    /** @notice This method delists a previously listed ticket of `ticketCollection` with `ticketID`. Only the account that
     * listed the ticket may delist the ticket. The ticket should be transferred back
     * to msg.sender, i.e., the lister, and escrowed bid funds should be return to the bidder, if any.
     */
    function delistTicket(address ticketCollection, uint256 ticketID) OnlyTicketOwner(ticketCollection, ticketID) external{
        emit Delisting(ticketCollection, ticketID);
        if (_listedTickets[ticketCollection][ticketID].maxBid > 0){
            // return the escrowed amount back to the max bidder
            _purchaseToken.transfer(_listedTickets[ticketCollection][ticketID].maxBidder, _listedTickets[ticketCollection][ticketID].maxBid);
        }
        TicketNFT collection = TicketNFT(ticketCollection);
        collection.transferFrom(address(this), msg.sender, ticketID);
        delete _listedTickets[ticketCollection][ticketID];
    }

    /** MY OWN METHOD, WHICH WILL BE USED IN CASES WHEN THE TICKET EXPIRES AND THE LISTER DOES NOT DELIST THE TICKET
     */
    function claimEscrowAmount(address ticketCollection, uint256 ticketID) external {
        require(msg.sender == _listedTickets[ticketCollection][ticketID].maxBidder, "You do not have permission to claim these funds");
        TicketNFT collection = TicketNFT(ticketCollection);
        if (collection.isExpiredOrUsed(ticketID)) {
            // return the escrowed amount back to the max bidder
            _purchaseToken.transfer(msg.sender, _listedTickets[ticketCollection][ticketID].maxBid);
            delete _listedTickets[ticketCollection][ticketID];
        }
    }

}
