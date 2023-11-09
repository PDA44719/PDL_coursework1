pragma solidity ^0.8.10;

import "../interfaces/ITicketNFT.sol";

contract TicketNFT { //is ITicketNFT to be added at the end
	string _collectionName;
	uint256 _ticketID = 1; // Initial ID value
	//string _currentTicketHolder; I believe a mapping is req for this 
	uint256 _validUntil;
	bool _hasBeenUsed = false;
	address _creator;
	uint256 _maxNumberOfTickets;

	// string memory currentTicketHolder (to be added as an argument)
	constructor(
		string memory collectionName,
		uint256 maxNumOfTickets,
		address collectionCreator
	) {
		_collectionName = collectionName;
		_maxNumberOfTickets = maxNumOfTickets;
		//_currentTicketHolder = currentTicketHolder;
		_validUntil = block.timestamp * 864000;
		_creator = collectionCreator;
	}

    function creator() external view returns (address){
		return _creator;
	}

    function getCollectionName() external view returns (string memory){
		return _collectionName;
	}

    function maxNumberOfTickets() external view returns (uint256){
		return _maxNumberOfTickets;
	}

} 
