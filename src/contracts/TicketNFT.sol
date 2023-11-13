pragma solidity ^0.8.10;

import "../interfaces/ITicketNFT.sol";

contract TicketNFT { //is ITicketNFT to be added at the end

    event Log (uint256 message);
	string _collectionName;
	uint256 _numberOfMintedTickets = 0; // No tokens minted in the beginning
	//string _currentTicketHolder; I believe a mapping is req for this 
	uint256 _validUntil;
	bool _hasBeenUsed = false;
	address _creator;
	uint256 _maxNumberOfTickets;
    mapping(uint256 => address) internal _holderOf;
    mapping(address => uint256) internal _balanceOf;
    mapping(address => string) internal _nameOf;

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

    function eventName() external view returns (string memory){
		return _collectionName;
	}

    function maxNumberOfTickets() external view returns (uint256){
		return _maxNumberOfTickets;
	}

    function getNumberOfMinted() external view returns (uint256){
        return _numberOfMintedTickets;
    }

    function mint(address holder, string memory holderName) external returns (uint256 id){
        uint256 newTokenID = _numberOfMintedTickets + 1;
        _holderOf[newTokenID] = holder;
        _nameOf[holder] = holderName;
        _balanceOf[holder]++;
        _numberOfMintedTickets++;
        return newTokenID;
    }

    function balanceOf(address holder) external view returns (uint256 balance){
        return _balanceOf[holder];
    }

    function holderOf(uint256 ticketID) external view returns (address holder){
        return _holderOf[ticketID];
    }

    function transferFrom(
        address from,
        address to,
        uint256 ticketID
    ) external{}

    function approve(address to, uint256 ticketID) external{}

    function getApproved(uint256 ticketID)
        external
        view
        returns (address operator){}

    function holderNameOf(uint256 ticketID)
        external
        view
        returns (string memory holderName){
            address holder = _holderOf[ticketID];
            return _nameOf[holder];
        }

    function updateHolderName(uint256 ticketID, string calldata newName)
        external{}

    function setUsed(uint256 ticketID) external{}

    function isExpiredOrUsed(uint256 ticketID) external view returns (bool){}
} 
