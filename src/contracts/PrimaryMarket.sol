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
    ) external returns (TicketNFT ticketCollection){ // This is to be changed to class ITicketCollection

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
			msg.sender
		);
		return collection;
		 
	}
}
