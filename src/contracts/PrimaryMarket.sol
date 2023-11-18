pragma solidity ^0.8.10;

import "../interfaces/IPrimaryMarket.sol";
import "../contracts/PurchaseToken.sol";
import "../contracts/TicketNFT.sol";

contract PrimaryMarket is IPrimaryMarket {
    event Log(address someone); // TO BE DELETED BEFORE SUBMITTING

    PurchaseToken _purchaseToken;
    mapping(address => uint256) internal _priceOfATicket;

    constructor(PurchaseToken purchaseToken) {
        _purchaseToken = purchaseToken;
    }

    function createNewEvent(
        string memory eventName,
        uint256 price,
        uint256 maxNumberOfTickets
    ) external returns (ITicketNFT ticketCollection) {
        // Create collection and define the ticket price
        TicketNFT collection = new TicketNFT(
            eventName,
            maxNumberOfTickets,
            msg.sender
        );
        _priceOfATicket[address(collection)] = price;

        emit EventCreated(
            msg.sender,
            address(collection),
            eventName,
            price,
            maxNumberOfTickets
        );
        return collection;
    }

    function getPrice(
        address ticketCollection
    ) external view returns (uint256 price) {
        return _priceOfATicket[ticketCollection];
    }

    function purchase(
        address ticketCollection,
        string memory holderName
    ) external returns (uint256 id) {
        // Ensure that sender has approved the amount and has sufficient funds
        require(
            _purchaseToken.allowance(msg.sender, address(this)) >=
                _priceOfATicket[ticketCollection],
            "Ticket price was not approved before purchase"
        );
        require(
            _purchaseToken.balanceOf(msg.sender) >=
                _priceOfATicket[ticketCollection],
            "Insufficient funds"
        );

        // Mint ticket and transfer purchase price to the collection creator
        TicketNFT collection = TicketNFT(ticketCollection);
        uint256 newTokenID = collection.mint(msg.sender, holderName);
        _purchaseToken.transferFrom(
            msg.sender,
            collection.creator(),
            _priceOfATicket[ticketCollection]
        );

        emit Purchase(msg.sender, ticketCollection, newTokenID, holderName);
        return newTokenID;
    }
}
