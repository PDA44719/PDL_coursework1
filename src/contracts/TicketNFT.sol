pragma solidity ^0.8.10;

import "../interfaces/ITicketNFT.sol";
import "../contracts/PrimaryMarket.sol";

contract TicketNFT is ITicketNFT {
    event Log(uint256 message);
    event Print(string check);

    struct TicketInfo {
        address holder;
        string holderName;
        uint256 validUntil;
        bool hasBeenUsed;
        address approved;
    }

    mapping(uint256 => TicketInfo) internal _tickets;
    string _collectionName;
    uint256 _numberOfMintedTickets = 0; // No tokens minted in the beginning
    address _creator;
    address _primaryMarket;
    uint256 _maxNumberOfTickets;
    mapping(address => uint256) internal _balanceOf;

    modifier TicketExists(uint256 ticketID) {
        require(
            ticketID > 0 && ticketID <= _numberOfMintedTickets,
            "Invalid ticket ID"
        );
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

    function creator() external view returns (address) {
        return _creator;
    }

    function eventName() external view returns (string memory) {
        return _collectionName;
    }

    function maxNumberOfTickets() external view returns (uint256) {
        return _maxNumberOfTickets;
    }

    function mint(
        address holder,
        string memory holderName
    ) external returns (uint256 id) {
        require(
            msg.sender == _primaryMarket,
            "Only the primary Market can mint tickets"
        );
        require(
            _numberOfMintedTickets < _maxNumberOfTickets,
            "No more tickets can be minted"
        );

        // Get the id of the new token and define its information
        uint256 newTokenID = _numberOfMintedTickets + 1; 
        _tickets[newTokenID] = TicketInfo({
            holder: holder,
            holderName: holderName,
            validUntil: block.timestamp + 864000,
            hasBeenUsed: false,
            approved: address(0)
        });

        // Update balance and the number of minted tokens
        _balanceOf[holder]++;
        _numberOfMintedTickets++;

        emit Transfer(address(0), holder, newTokenID);
        return newTokenID;
    }

    function balanceOf(address holder) external view returns (uint256 balance) {
        return _balanceOf[holder];
    }

    function holderOf(
        uint256 ticketID
    ) external view TicketExists(ticketID) returns (address holder) {
        return _tickets[ticketID].holder;
    }

    function transferFrom(
        address from,
        address to,
        uint256 ticketID
    ) external TicketExists(ticketID) {
        require(
            from != address(0),
            "'from' address cannot be the zero address"
        );
        require(to != address(0), "'to' address cannot be the zero address");
        require(
            _tickets[ticketID].holder == msg.sender ||
                _tickets[ticketID].approved == msg.sender,
            "Permission error: Ticket could not be transferred"
        );

        // Update the holder and balance information
        _tickets[ticketID].holder = to;
        _balanceOf[to]++;
        _balanceOf[from]--;

        // Reset approval every time a transfer takes place 
        _tickets[ticketID].approved = address(0);

        emit Transfer(from, to, ticketID);
        emit Approval(to, address(0), ticketID);
    }

    function approve(
        address to,
        uint256 ticketID
    ) external TicketExists(ticketID) {
        require(
            _tickets[ticketID].holder == msg.sender,
            "You do not own that ticket"
        );

        _tickets[ticketID].approved = to;
        emit Approval(msg.sender, to, ticketID);
    }

    function getApproved(
        uint256 ticketID
    ) external view TicketExists(ticketID) returns (address operator) {
        return _tickets[ticketID].approved;
    }

    function holderNameOf(
        uint256 ticketID
    ) external view TicketExists(ticketID) returns (string memory holderName) {
        return _tickets[ticketID].holderName;
    }

    function updateHolderName(
        uint256 ticketID,
        string calldata newName
    ) external TicketExists(ticketID) {
        require(
            msg.sender == _tickets[ticketID].holder,
            "Only the ticket holder can update the name"
        );

        _tickets[ticketID].holderName = newName;
    }

    function setUsed(uint256 ticketID) external TicketExists(ticketID) {
        require(
            _tickets[ticketID].hasBeenUsed != true,
            "The ticket had already been used"
        );
        require(
            block.timestamp < _tickets[ticketID].validUntil,
            "The ticket has already expired"
        );
        require(
            msg.sender == _creator,
            "Only the collection creator can call this function"
        );

        _tickets[ticketID].hasBeenUsed = true;
    }

    function isExpiredOrUsed(
        uint256 ticketID
    ) external view TicketExists(ticketID) returns (bool) {
        // Check if the current time is greater than the expiry time
        bool isExpired = block.timestamp >= _tickets[ticketID].validUntil;
        return _tickets[ticketID].hasBeenUsed || isExpired;
    }
}
