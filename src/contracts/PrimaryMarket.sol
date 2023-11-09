pragma solidity ^0.8.10;

import "../interfaces/IPrimaryMarket.sol";
import "../contracts/PurchaseToken.sol";
import "../contracts/TicketNFT.sol";

contract PrimaryMarket { //is IPrimaryMarket to be added
	PurchaseToken _purchaseToken;

	constructor(PurchaseToken purchaseToken){
		_purchaseToken = purchaseToken;
	}

    function createNewEvent(
        string memory eventName,
        uint256 price,
        uint256 maxNumberOfTickets
    ) external returns (ITicketNFT ticketCollection){
		TicketNFT collection = new TicketNFT(
			eventName,
			"alice",
			msg.sender
		);
	}
}
