pragma solidity ^0.8.10;

import "../interfaces/ITicketNFT.sol";

contract TicketNFT { //is ITicketNFT to be added at the end
	string _name;
	uint256 _ticketID = 1; // Initial ID value
	string _currentTicketHolder;
	uint256 _validUntil;
	bool _hasBeenUsed = false;
	address _creator;

	constructor(
		string memory name,
		string memory currentTicketHolder,
		address creator
	) {
		_name = name;
		_currentTicketHolder = currentTicketHolder;
		_validUntil = block.timestamp * 864000;
		_creator = creator;
	}

    function creator() external view returns (address){
		return _creator;
	}

} 
