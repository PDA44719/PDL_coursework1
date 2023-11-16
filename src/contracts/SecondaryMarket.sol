
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;


import "../interfaces/ISecondaryMarket.sol";
import "../contracts/PurchaseToken.sol";
import "../contracts/TicketNFT.sol";

contract SecondaryMarket { //is ISecondaryMarket // to be added at some point

    mapping(address => mapping(uint256 => address)) internal _listedTicketsAndOwners;
    mapping(address => mapping(uint256 => uint256)) internal _listedTicketPrices;
    mapping(address => mapping(uint256 => uint256)) internal _maxTicketBid;
    mapping(address => mapping(uint256 => address)) internal _maxBidderAddress;
    mapping(address => mapping(uint256 => string)) internal _maxBidName;
	PurchaseToken _purchaseToken;

    modifier OnlyTicketOwner(address ticketCollection, uint256 ticketID) {
        TicketNFT collection = TicketNFT(ticketCollection);
        require(msg.sender == collection.holderOf(ticketID) || _listedTicketsAndOwners[ticketCollection][ticketID] == msg.sender, "Only the ticket owner can call this function");
        _;
        // SHOULD ADD SOME CHECK HERE TO MAKE SURE THAT THE ESCROWED AMOUNT GETS RETURNED AFTER THE TICKET HAS EXPIRED
    }

    modifier NonExpiredAndUnused(address ticketCollection, uint256 ticketID) {
        TicketNFT collection = TicketNFT(ticketCollection);
        require(collection.isExpiredOrUsed(ticketID) == false, "The ticket has already expired/been used");
        _;
    }

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
        _listedTicketsAndOwners[ticketCollection][ticketID] = msg.sender;
        _listedTicketPrices[ticketCollection][ticketID] = price; // I have not 
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
        if (_maxTicketBid[ticketCollection][ticketID] == 0){  // No bid has been made yet
            require(bidAmount >= _listedTicketPrices[ticketCollection][ticketID], "The initial bid must be greater than the listing price");
        } else {
            require(bidAmount > _maxTicketBid[ticketCollection][ticketID], "Your bid must be greater than the current max bid");

            // return the escrowed amount to back the previous max bidder
            _purchaseToken.transfer(_maxBidderAddress[ticketCollection][ticketID], _maxTicketBid[ticketCollection][ticketID]);
        }
        emit BidSubmitted(msg.sender, ticketCollection, ticketID, bidAmount, name);
        TicketNFT collection = TicketNFT(ticketCollection);
        collection.transferFrom(msg.sender, address(this), bidAmount);
        _maxTicketBid[ticketCollection][ticketID] = bidAmount;
        _maxBidderAddress[ticketCollection][ticketID] = msg.sender;
        _maxBidName[ticketCollection][ticketID] = name;
    }

    /**
     * Returns the current highest bid for the ticket from `ticketCollection` with `ticketID`
     */
    function getHighestBid(
        address ticketCollection,
        uint256 ticketId
    ) external view returns (uint256){
        return _maxTicketBid[ticketCollection][ticketId];
    }

    /**
     * Returns the current highest bidder for the ticket from `ticketCollection` with `ticketID`
     */
    function getHighestBidder(
        address ticketCollection,
        uint256 ticketId
    ) external view returns (address){
        return _maxBidderAddress[ticketCollection][ticketId];
    }

    function _deleteMappingEntries(address ticketCollection, uint256 ticketID) private {
        delete _listedTicketsAndOwners[ticketCollection][ticketID];
        delete _listedTicketPrices[ticketCollection][ticketID];
        delete _maxTicketBid[ticketCollection][ticketID];
        delete _maxBidderAddress[ticketCollection][ticketID];
        delete _maxBidName[ticketCollection][ticketID];
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
    function acceptBid(address ticketCollection, uint256 ticketID) OnlyTicketOwner(ticketCollection, ticketID) external{
        require(_maxTicketBid[ticketCollection][ticketID] != 0, "No bids have been made yet");
        TicketNFT collection = TicketNFT(ticketCollection);
        _purchaseToken.transferFrom(_maxBidderAddress[ticketCollection][ticketID], msg.sender, _maxTicketBid[ticketCollection][ticketID] * 95 / 100);
        _purchaseToken.transferFrom(_maxBidderAddress[ticketCollection][ticketID], collection.creator(), _maxTicketBid[ticketCollection][ticketID] * 5 / 100);
        collection.transferFrom(msg.sender, _maxBidderAddress[ticketCollection][ticketID], ticketID);
        _deleteMappingEntries(ticketCollection, ticketID);
    }

    /** @notice This method delists a previously listed ticket of `ticketCollection` with `ticketID`. Only the account that
     * listed the ticket may delist the ticket. The ticket should be transferred back
     * to msg.sender, i.e., the lister, and escrowed bid funds should be return to the bidder, if any.
     */
    function delistTicket(address ticketCollection, uint256 ticketID) OnlyTicketOwner(ticketCollection, ticketID) external{
        // return the escrowed amount to back the previous max bidder
        _purchaseToken.transfer(_maxBidderAddress[ticketCollection][ticketID], _maxTicketBid[ticketCollection][ticketID]);
        _deleteMappingEntries(ticketCollection, ticketID);
    }

}
