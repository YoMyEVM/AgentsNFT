// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "./ERC721.sol";
import "./ERC721Enumerable.sol";
import "./ERC721URIStorage.sol";
import "./Strings.sol";
import "./Ownable.sol";
import "./Address.sol";
import "./SafeMath.sol";
import "./ReentrancyGuard.sol";


contract ISAI is ERC721, ERC721Enumerable, ERC721URIStorage, Ownable, ReentrancyGuard {

    using Address for address payable;
    using SafeMath for uint256;

    uint256 public constant MAX_ISAI = 10000;
    uint256 public constant MAX_PURCHASE = 6;
    uint256 public constant AMOUNT_RESERVED = 120;
    uint256 public constant ISAI_PRICE = 9E16; // 0.09ETH
    uint256 public constant RENAME_PRICE = 9E15; // 0.009ETH


    enum State {
        Setup,
        PreParty,
        Party
    }

    mapping(address => uint256) private _authorised;

    mapping(uint256 => bool) private _nameChanged;


    State private _state;


    string private _immutableIPFSBucket;
    string private _mutableIPFSBucket;
    string private _tokenUriBase; 


    uint256 _nextTokenId;
    uint256 _startingIndex;


    function setStartingIndexAndMintReserve(address reserveAddress) public {
        require(_startingIndex == 0, "Starting index is already set.");
        
        _startingIndex = uint256(blockhash(block.number - 1)) % MAX_ISAI;
   
        // Prevent default sequence
        if (_startingIndex == 0) {
            _startingIndex = _startingIndex.add(1);
        }

        _nextTokenId = _startingIndex;


        for(uint256 i = 0; i < AMOUNT_RESERVED; i++) {
            _safeMint(reserveAddress, _nextTokenId); 
            _nextTokenId = _nextTokenId.add(1).mod(MAX_ISAI); 
        }
    }

	event NameAndDescriptionChanged(uint256 indexed _tokenId, string _name, string _description);

  
    constructor() ERC721("ISAI","ISAI") {
        _state = State.Setup;
    }

    function setImmutableIPFSBucket(string memory immutableIPFSBucket_) public onlyOwner {
        require(bytes(_immutableIPFSBucket).length == 0, "This IPFS bucket is immuable and can only be set once.");
        _immutableIPFSBucket = immutableIPFSBucket_;
    }

    function setMutableIPFSBucket(string memory mutableIPFSBucket_) public onlyOwner {
        _mutableIPFSBucket = mutableIPFSBucket_;
    }

    function setTokenURI(string memory tokenUriBase_) public onlyOwner {
        _tokenUriBase = tokenUriBase_;
    }


    function changeNameAndDescription(uint256 tokenId, string memory newName, string memory newDescription) public payable {
        address owner = ERC721.ownerOf(tokenId);

        require(
            _msgSender() == owner,
            "This isn't your Agent."
        );

        uint256 amountPaid = msg.value;

        if(_nameChanged[tokenId]) {
            require(amountPaid == RENAME_PRICE, "It costs to create a new identity.");
        } else {
            require(amountPaid == 0, "First time's free.");
            _nameChanged[tokenId] = true;
        }

        emit NameAndDescriptionChanged(tokenId, newName, newDescription);
    }


    function _beforeTokenTransfer(address from, address to, uint256 tokenId)
        internal
        override(ERC721, ERC721Enumerable)
    {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }
 


    function baseTokenURI() virtual public view returns (string memory) {
        return _tokenUriBase;
    }

    function state() virtual public view returns (State) {
        return _state;
    }

    function immutableIPFSBucket() virtual public view returns (string memory) {
        return _immutableIPFSBucket;
    }

    function mutableIPFSBucket() virtual public view returns (string memory) {
        return _mutableIPFSBucket;
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {

        return string(abi.encodePacked(baseTokenURI(), Strings.toString(tokenId)));
 
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }


    function startPreParty() public onlyOwner {
        require(_state == State.Setup);
        _state = State.PreParty;
    }

    function setStateToParty() public onlyOwner {
        _state = State.Party;
    }


    function mintIsai(address human, uint256 amountOfIsais) public nonReentrant payable virtual returns (uint256) {

        require(_state != State.Setup, "Agents aren't ready yet!");
        require(amountOfIsais <= MAX_PURCHASE, "Hey, that's too many Agents. Save some for the rest of us!");

        require(totalSupply().add(amountOfIsais) <= MAX_ISAI, "Sorry, there's not that many Agents left.");
        require(ISAI_PRICE.mul(amountOfIsais) <= msg.value, "Hey, that's not the right price.");


        if(_state == State.PreParty) {
            require(_authorised[human] >= amountOfIsais, "Hey, you're not allowed to buy this many Agents during the pre-party.");
            _authorised[human] -= amountOfIsais;
        }

        uint256 firstIsaiRecieved = _nextTokenId;

        for(uint i = 0; i < amountOfIsais; i++) {
            _safeMint(human, _nextTokenId); 
            _nextTokenId = _nextTokenId.add(1).mod(MAX_ISAI); 
        }

        return firstIsaiRecieved;

    }

     function withdrawAllEth(address payable payee) public virtual onlyOwner {
        payee.sendValue(address(this).balance);
    }


    function authoriseIsai(address human, uint256 amountOfIsais)
        public
        onlyOwner
    {
      _authorised[human] += amountOfIsais;
    }


    function authoriseIsaiBatch(address[] memory humans, uint256 amountOfIsais)
        public
        onlyOwner
    {
        for (uint8 i = 0; i < humans.length; i++) {
            authoriseIsai(humans[i], amountOfIsais);
        }
    }

}