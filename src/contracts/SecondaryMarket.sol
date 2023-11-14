
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;


import "../interfaces/ISecondaryMarket.sol";
import "../contracts/TicketNFT.sol";

contract SecondaryMarket { //is ISecondaryMarket // to be added at some point

    mapping(uint256 => address) internal _listedTicketsAndOwners;

    modifier OnlyTicketOwner(address ticketCollection, uint256 ticketID) {
        TicketNFT collection = TicketNFT(ticketCollection);
        require(msg.sender == collection.holderOf(ticketID), "Only the ticket owner can call this function");
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

    /**
     * @dev This method lists a ticket with `ticketID` for sale by transferring the ticket
     * such that it is held by this contract. Only the current owner of a specific
     * ticket is able to list that ticket on the secondary market. The purchase
     * `price` is specified in an amount of `PurchaseToken`.
     * Note: Only non-expired and unused tickets can be listed
     */
    function listTicket(
        address ticketCollection,
        uint256 ticketID,
        uint256 price
    ) OnlyTicketOwner(ticketCollection, ticketID) external{
        TicketNFT collection = TicketNFT(ticketCollection);
        collection.transferFrom(msg.sender, address(this), ticketID);
        
    }

    /*function submitBid(
        address ticketCollection,
        uint256 ticketID,
        uint256 bidAmount,
        string calldata name
    ) external;

    function getHighestBid(
        address ticketCollection,
        uint256 ticketId
    ) external view returns (uint256);

    function getHighestBidder(
        address ticketCollection,
        uint256 ticketId
    ) external view returns (address);

    function acceptBid(address ticketCollection, uint256 ticketID) external;

    function delistTicket(address ticketCollection, uint256 ticketID) external;
*/
}
