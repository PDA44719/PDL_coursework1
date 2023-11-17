pragma solidity ^0.8.10;

import "../interfaces/ITicketNFT.sol";
import "../contracts/PrimaryMarket.sol";

contract TicketNFT is ITicketNFT{ 
    event Log(bytes4 message);

    struct TicketInfo {
        address _holder;
        string _holderName;
        uint256 _validUntil;
        bool _hasBeenUsed;
        address _hasApproval;
    }

    mapping(uint256 => TicketInfo) internal _tickets;
	string _collectionName;
	uint256 _numberOfMintedTickets = 0; // No tokens minted in the beginning
	address _creator;
	address _primaryMarket;
	uint256 _maxNumberOfTickets;
    mapping(address => uint256) internal _balanceOf;

    modifier TicketExists(uint256 ticketID) {
        require(ticketID > 0 && ticketID <= _numberOfMintedTickets, "Invalid ticketID");
        _;
    }

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
        _tickets[newTokenID] = TicketInfo({
            _holder: holder,
            _holderName: holderName,
            _validUntil: block.timestamp * 864000,
            _hasBeenUsed: false,
            _hasApproval: address(0)
        });
        _balanceOf[holder]++;
        _numberOfMintedTickets++;
        emit Transfer(address(0), holder, newTokenID);
        return newTokenID;
    }

    function balanceOf(address holder) external view returns (uint256 balance){
        return _balanceOf[holder];
    }

    function holderOf(uint256 ticketID) TicketExists(ticketID) external view returns (address holder){
        return _tickets[ticketID]._holder;
    }

    function transferFrom(
        address from,
        address to,
        uint256 ticketID
    ) TicketExists(ticketID) external{
        require(from != address(0), "'from' address cannot be the zero address");
        require(to != address(0), "'to' address cannot be the zero address");
        require(_tickets[ticketID]._holder == msg.sender || _tickets[ticketID]._hasApproval == msg.sender, "You do not have the right to transfer that ticket");
        _tickets[ticketID]._holder = to;
        _balanceOf[to]++;
        _balanceOf[from]--;
        _tickets[ticketID]._hasApproval = address(0);
        emit Transfer(from, to, ticketID);
        emit Approval(to, address(0), ticketID);
    }

    function approve(address to, uint256 ticketID) TicketExists(ticketID) external{
        require(_tickets[ticketID]._holder == msg.sender, "You do not own that ticket");
        _tickets[ticketID]._hasApproval = to;
        emit Approval(msg.sender, to, ticketID);
    }

    function getApproved(uint256 ticketID)
        TicketExists(ticketID) external
        view
        returns (address operator){
            return _tickets[ticketID]._hasApproval;
        }

    function holderNameOf(uint256 ticketID)
        TicketExists(ticketID) external
        view
        returns (string memory holderName){
            return _tickets[ticketID]._holderName;
        }

    function updateHolderName(uint256 ticketID, string calldata newName)
        TicketExists(ticketID) external{
            address holder = _tickets[ticketID]._holder;
            require(msg.sender == holder, "You have no permission to update the holder's name");
            _tickets[ticketID]._holderName = newName;
        }

    function setUsed(uint256 ticketID) TicketExists(ticketID) external{
        require(_tickets[ticketID]._hasBeenUsed != true, "The ticket had already been used");
        require(block.timestamp >= _tickets[ticketID]._validUntil, "The ticket has already expired");
        require(msg.sender == _creator, "Only the creator can call this function");
        _tickets[ticketID]._hasBeenUsed = true;
    }

    function isExpiredOrUsed(uint256 ticketID) TicketExists(ticketID) external view returns (bool){
        bool isExpired = block.timestamp >= _tickets[ticketID]._validUntil;
        return _tickets[ticketID]._hasBeenUsed || isExpired;
    }
} 
