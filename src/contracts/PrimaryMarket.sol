pragma solidity ^0.8.10;

import "../interfaces/IPrimaryMarket.sol";
import "../contracts/PurchaseToken.sol";
import "../contracts/TicketNFT.sol";

contract PrimaryMarket is IPrimaryMarket{ //is IPrimaryMarket to be added
	/* This section is to be deleted before submission, as the interface 
	already has these events, so there is no need to add them here*/

    event Log(address someone);
	/* End of Section to be Deleted */

	PurchaseToken _purchaseToken;
	mapping(address => uint256) internal priceOfATicket;

	constructor(PurchaseToken purchaseToken){
		_purchaseToken = purchaseToken;
	}

    function createNewEvent(
        string memory eventName,
        uint256 price,
        uint256 maxNumberOfTickets
    ) external returns (ITicketNFT ticketCollection){ 

		/*bytes memory callData = abi.encodePacked(
            type(TicketNFT).creationCode,
            abi.encode(eventName, msg.sender)
        );
		
		address newTicketNFT;
		assembly {
            newTicketNFT := create(0, add(callData, 0x20), mload(callData))
            if iszero(extcodesize(newTicketNFT)) {
                revert(0, 0)
            }
        }
		return TicketNFT(newTicketNFT);
		*/
		
		TicketNFT collection = new TicketNFT(
			eventName,
			maxNumberOfTickets,
			msg.sender
		);
		priceOfATicket[address(collection)] = price;
		emit EventCreated(msg.sender, address(collection), eventName, 
						 price, maxNumberOfTickets);
		return TicketNFT(collection);
		 
	}

    function getPrice(
        address ticketCollection
    ) external view returns (uint256 price){
		return priceOfATicket[ticketCollection];
	}

    function purchase(
        address ticketCollection,
        string memory holderName
    ) external returns (uint256 id){
        TicketNFT collection = TicketNFT(ticketCollection);
        // Check that more tickets can be minted
        require(collection.getNumberOfMinted() < collection.maxNumberOfTickets(), "No more tickets can be minted");

        // Check that the buyer has enough funds and has approved the amount
        require(_purchaseToken.allowance(msg.sender, address(this)) >= priceOfATicket[ticketCollection], "Ticket price was not approved before purchase");
        require(_purchaseToken.balanceOf(msg.sender) >= priceOfATicket[ticketCollection], "Insufficient funds");

        uint256 newTokenID = collection.mint(msg.sender, holderName);
        emit Purchase(msg.sender, ticketCollection, newTokenID, holderName);
        _purchaseToken.transferFrom(msg.sender, collection.creator(), priceOfATicket[ticketCollection]);
        return newTokenID;
    }
}
