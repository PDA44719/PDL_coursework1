pragma solidity ^0.8.10;

import "../interfaces/ITicketNFT.sol";
import "../contracts/PrimaryMarket.sol";

contract TicketNFT is ITicketNFT{ 
    event Log(bytes4 message);
	string _collectionName;
	uint256 _numberOfMintedTickets = 0; // No tokens minted in the beginning
	address _creator;
	address _primaryMarket;
	uint256 _maxNumberOfTickets;
    mapping(uint256 => address) internal _holderOf;
    mapping(address => uint256) internal _balanceOf;
    mapping(uint256 => string) internal _holderNameOf;
	mapping(uint256 => uint256) internal _validUntil;
    mapping(uint256 => bool) internal _hasBeenUsed;
    mapping(address => mapping(uint256 => address)) internal _hasApproval;

    modifier TicketExists(uint256 ticketID) {
        require(ticketID > 0 && ticketID <= _numberOfMintedTickets, "Invalid ticketID");
        _;
    }

	// string memory currentTicketHolder (to be added as an argument)
	constructor(
		string memory collectionName,
		uint256 maxNumOfTickets,
		address collectionCreator
	) {
		_collectionName = collectionName;
		_maxNumberOfTickets = maxNumOfTickets;
		_creator = collectionCreator;
        _primaryMarket = msg.sender;
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
        require(msg.sender == _primaryMarket, "Only the primary Market can mint tickets");
        uint256 newTokenID = _numberOfMintedTickets + 1;
        _holderOf[newTokenID] = holder;
        _holderNameOf[newTokenID] = holderName;
        _balanceOf[holder]++;
        _numberOfMintedTickets++;
        _hasBeenUsed[newTokenID] = false;
		_validUntil[newTokenID] = block.timestamp * 864000;
        emit Transfer(address(0), holder, newTokenID);
        return newTokenID;
    }

    function balanceOf(address holder) external view returns (uint256 balance){
        return _balanceOf[holder];
    }

    function holderOf(uint256 ticketID) TicketExists(ticketID) external view returns (address holder){
        return _holderOf[ticketID];
    }

    function transferFrom(
        address from,
        address to,
        uint256 ticketID
    ) TicketExists(ticketID) external{
        // SHOULD WORRY ABOUT THE 0 ADDRESS PART
        require(_holderOf[ticketID] == msg.sender || _hasApproval[from][ticketID] == msg.sender, "You do not have the right to transfer that ticket");
        emit Transfer(from, to, ticketID);
        _holderOf[ticketID] = to;
        _balanceOf[to]++;
        _balanceOf[from]--;
    }

    function approve(address to, uint256 ticketID) TicketExists(ticketID) external{
        require(_holderOf[ticketID] == msg.sender, "You do not own that ticket");
        emit Approval(msg.sender, to, ticketID);
        _hasApproval[msg.sender][ticketID] = to;
    }

    function getApproved(uint256 ticketID)
        TicketExists(ticketID) external
        view
        returns (address operator){
            return _hasApproval[_holderOf[ticketID]][ticketID];
        }

    function holderNameOf(uint256 ticketID)
        TicketExists(ticketID) external
        view
        returns (string memory holderName){
            return _holderNameOf[ticketID];
        }

    function updateHolderName(uint256 ticketID, string calldata newName)
        TicketExists(ticketID) external{
            address holder = _holderOf[ticketID];
            require(msg.sender == holder, "You have no permission to update the holder's name");
            _holderNameOf[ticketID] = newName;
        }

    function setUsed(uint256 ticketID) TicketExists(ticketID) external{
        require(_hasBeenUsed[ticketID] != true, "The ticket had already been used");
        require(block.timestamp >= _validUntil[ticketID], "The ticket has already expired");
        require(msg.sender == _creator, "Only the creator can call this function");
        _hasBeenUsed[ticketID] = true;
    }

    function isExpiredOrUsed(uint256 ticketID) TicketExists(ticketID) external view returns (bool){
        bool isExpired = block.timestamp >= _validUntil[ticketID];
        return _hasBeenUsed[ticketID] && isExpired;
    }
} 
