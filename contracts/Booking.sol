//SPDX-License-Identifier: MIT
// Art by @walshe_steve // Copyright © Steve Walshe
// Code by @0xGeeLoko

pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Booking is ERC721, Ownable, ReentrancyGuard {
    using Strings for string;

    address erc20Contract = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48; // USDC ethereum mainnet

    bool public mintingIsActive = false;
    
    string public baseTokenURI;

    uint256 public mintPrice; // 4500 * 10 ** 6; // 4500 USDC (mainnet value)

    uint256 public totalSupply;

    address payable public artist; //  = payable(0x7ea9114092eC4379FFdf51bA6B72C71265F33e96);

    event Attest(address indexed to, uint256 indexed tokenId);
    event Revoke(address indexed to, uint256 indexed tokenId);

    constructor() ERC721("Booking Template", "Booking") {}

    /*
    * Withdraw funds
    */
    function withdraw() external nonReentrant
    {
        require(msg.sender == artist || msg.sender == owner(), "Invalid sender");
        (bool success, ) = artist.call{value: address(this).balance / 100 * 2}(""); 
        (bool success2, ) = owner().call{value: address(this).balance}(""); 
        require(success, "Transfer 1 failed");
        require(success2, "Transfer 2 failed");
    }

    function withdrawERC20() external nonReentrant
    {
        require(msg.sender == artist || msg.sender == owner(), "Invalid sender");
        IERC20 tokenContract = IERC20(erc20Contract);

        uint256 totalBalance = tokenContract.balanceOf(address(this));
        uint256 artistSplit = totalBalance / 100 * 85; // set split
        uint256 ownerSplit = totalBalance - artistSplit;

        bool artistTransfer = tokenContract.transfer(artist, artistSplit);
        bool ownerTransfer = tokenContract.transfer(owner(), ownerSplit);

        require(artistTransfer, "Transfer 1 failed");
        require(ownerTransfer, "Transfer 2 failed");
    }

    /*
    * Change price - USDC per token (remember USDC contracts only have 6 decimal places)
    */
    function setMintPrice(uint256 newPrice) public onlyOwner {
        mintPrice = newPrice;
    }

    /*
    * Change artist payout wallet 
    */
    function setPayAddress(address payable newAddress) public {
        require(msg.sender == artist || msg.sender == owner(), "Invalid sender");
        artist = newAddress;
    }

    //---------------------------------------------------------------------------------
    /**
    * Current on-going collection that is avaiable to BioUpgrade or use as base for minting
    */
    function setBaseTokenURI(string memory newuri) public onlyOwner {
        baseTokenURI = newuri;
    }

    /*
    * Pause minting if active, make active if paused
    */
    function flipMintState() public onlyOwner {
        mintingIsActive = !mintingIsActive;
    }

    

    /**
     * public booking
     */
    function book() 
    external
    nonReentrant
    {
        require(msg.sender == tx.origin, "No contract transactions!");
        require(mintingIsActive, "booking not active");


        IERC20 tokenContract = IERC20(erc20Contract);

        bool transferred = tokenContract.transferFrom(msg.sender, address(this), mintPrice);
        require(transferred, "failed transfer");   

        uint256 tokenId = totalSupply;

        _safeMint(msg.sender, tokenId);

        totalSupply += 1;

        
    }


    /// ERC721 related
    /**
     * @dev See {ERC721Metadata-tokenURI}.
     */
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_exists(tokenId), "nonexistent token");

        string memory baseURI = _baseURI();
        return string(abi.encodePacked(baseURI, Strings.toString(tokenId), '.json'));
    }

    function _baseURI() internal view override returns (string memory) {
        return baseTokenURI;
    }

    function burn(uint256 tokenId) external {
        require(ownerOf(tokenId) == msg.sender, "not token owner");
        _burn(tokenId);
    }

    function revoke(uint256 tokenId) onlyOwner external {
        _burn(tokenId);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override virtual {
        require(from == address(0) || to == address(0), "can't transfer token");
    }

    function _afterTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override virtual {
        if (from == address(0)) {
            emit Attest(to, tokenId);
        } else if (to == address(0)) {
            emit Revoke(to, tokenId);
        }
    }

}