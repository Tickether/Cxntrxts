//SPDX-License-Identifier: MIT
// Code by @0xGeeLoko

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./IERC4907.sol";

contract Solscribe is ERC721, IERC4907, Ownable, ReentrancyGuard {
    using Strings for string;

    address erc20Contract = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48; // USDC ethereum mainnet

    bool public subscriptionIsActive = false;
    

    uint256 public maxMonthlySubs = 12;

    uint256 public subscriptionFee; // 4500 * 10 ** 6; // 4500 USDC (mainnet value)

    uint256 public totalSupply;

    string public baseTokenURI;

    address payable public treasury; //  = payable(0x7ea9114092eC4379FFdf51bA6B72C71265F33e96);

   
    mapping (address => bool) public subscribed;

    mapping (uint256  => UserInfo) internal _users;
    
    struct UserInfo {
        address user;   // address of user role
        uint64 expires; // unix timestamp, user expires
    }


    event Attest(address indexed to, uint256 indexed tokenId);
    event Revoke(address indexed to, uint256 indexed tokenId);


    constructor() ERC721("Subscription Template", "Subscription") {}
    
    /*
    * Withdraw funds
    */
    function withdraw() external nonReentrant
    {
        require(msg.sender == treasury || msg.sender == owner(), "Invalid sender");
        (bool success, ) = treasury.call{value: address(this).balance / 100 * 90}(""); 
        (bool success2, ) = owner().call{value: address(this).balance}(""); 
        require(success, "Transfer 1 failed");
        require(success2, "Transfer 2 failed");
    }

    function withdrawERC20() external nonReentrant
    {
        require(msg.sender == treasury || msg.sender == owner(), "Invalid sender");
        IERC20 tokenContract = IERC20(erc20Contract);

        uint256 totalBalance = tokenContract.balanceOf(address(this));
        uint256 treasurySplit = totalBalance / 100 * 90; // set split
        uint256 ownerSplit = totalBalance - treasurySplit;

        bool treasuryTransfer = tokenContract.transfer(treasury, treasurySplit);
        bool ownerTransfer = tokenContract.transfer(owner(), ownerSplit);

        require(treasuryTransfer, "Transfer 1 failed");
        require(ownerTransfer, "Transfer 2 failed");
    }

    /*
    * Change subscription price - USDC per token (remember USDC contracts only have 6 decimal places)
    */
    function setSubscriptionFee(uint256 newSubscriptionFee) public onlyOwner {
        subscriptionFee = newSubscriptionFee;
    }

    /*
    * Change max monthly subscription cap
    */
    function setMaxMonthlySubs(uint256 newMaxMonthlySubs) public onlyOwner {
        maxMonthlySubs = newMaxMonthlySubs;
    }

    /*
    * Change treasury payout wallet 
    */
    function setPayAddress(address payable newTreasuryAddress) public {
        require(msg.sender == treasury || msg.sender == owner(), "Invalid sender");
        treasury = newTreasuryAddress;
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
    function flipSubscriptionState() public onlyOwner {
        subscriptionIsActive = !subscriptionIsActive;
    }

    
    /// @notice set the user and expires of an NFT
    /// @dev The zero address indicates there is no user
    /// Throws if `tokenId` is not valid NFT
    /// @param user  The new user of the NFT
    /// @param expires  UNIX timestamp, The new user could use the NFT before expires
    function setUser(uint256 tokenId, address user, uint64 expires) public virtual override{
        require(msg.sender == tx.origin, "No contract transactions!");
        require(_isApprovedOrOwner(msg.sender, tokenId), "yo, cant do that shit lol");
        require(subscriptionIsActive, "subscription not active");
        require(subscribed[msg.sender], "no subscription token, cannot renew");
        require(expires <= maxMonthlySubs, "Exceeds max sub period");
        

        IERC20 tokenContract = IERC20(erc20Contract);

        uint256 compondedFee = subscriptionFee * expires;

        bool transferred = tokenContract.transferFrom(msg.sender, address(this), compondedFee);
        require(transferred, "failed transfer");   


        uint64 subscriptionPeriod = expires * 2592000; // timestamp for 30days multiplied by months to expire 
        
        UserInfo storage info =  _users[tokenId];
        require(info.expires < block.timestamp, "user already subscribed");
        
        info.user = user;
        info.expires = subscriptionPeriod;
        emit UpdateUser(tokenId, user, subscriptionPeriod);
    }


    /// @notice Get the user address of an NFT
    /// @dev The zero address indicates that there is no user or the user is expired
    /// @param tokenId The NFT to get the user address for
    /// @return The user address for this NFT
    function userOf(uint256 tokenId) public view virtual override returns(address){
        if( uint256(_users[tokenId].expires) >=  block.timestamp){
            return  _users[tokenId].user;
        }
        else{
            return address(0);
        }
    }


    /// @notice Get the user expires of an NFT
    /// @dev The zero value indicates that there is no user
    /// @param tokenId The NFT to get the user expires for
    /// @return The user expires for this NFT
    function userExpires(uint256 tokenId) public view virtual override returns(uint256){
        if( uint256(_users[tokenId].expires) >=  block.timestamp){
            return  _users[tokenId].expires;
        }
        else{
            return uint256(1000000000000000000000000000000000000000000000000000000000000);
        }
    }


    /**
     * public subscription
     */
    function getSubscriptionToken() 
    external
    nonReentrant
    {
        require(msg.sender == tx.origin, "No contract transactions!");
        require(subscriptionIsActive, "subscription not active");
        require(!subscribed[msg.sender], "already have subscription token");

        uint256 tokenId = totalSupply;


        _safeMint(msg.sender, tokenId);
        
        totalSupply += 1;
        subscribed[msg.sender] = true;

        
    }

    /** 
     *  
    */


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

    
    /// @dev See {IERC165-supportsInterface}.
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IERC4907).interfaceId || super.supportsInterface(interfaceId);
    }

    
    function revoke(uint256 tokenId) onlyOwner external {
        _burn(tokenId);
        subscribed[msg.sender] = false;
    }


    function _beforeTokenTransfer(
        address from,
        address to,
        uint256, /* firstTokenId */
        uint256 batchSize
    ) internal virtual override {
        

        require(from == address(0) || to == address(0), "can't transfer token");
        
        /*
        if (from != to && _users[tokenId].user != address(0)) {
            delete _users[tokenId];
            emit UpdateUser(tokenId, address(0), 0);
        }
        */
    }


    function _afterTokenTransfer(
        address from,
        address to,
        uint256 firstTokenId,
        uint256 batchSize
    ) internal virtual override  {
        if (from == address(0)) {
            emit Attest(to, firstTokenId);
        } else if (to == address(0)) {
            emit Revoke(to, firstTokenId);
        }
    }

}