//SPDX-License-Identifier: MIT
//Code by @0xGeeLoko



pragma solidity ^0.8.9;



import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./IERC4907.sol";



contract Solscription is ERC721, IERC4907, Ownable, ReentrancyGuard {

    string public baseTokenURI;



    address erc20Contract = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48; // USDC on evm mainnet

    address payable public solscriptionTreasury = payable(0x7ea9114092eC4379FFdf51bA6B72C71265F33e96);



    bool public subscriptionIsActive = false;

    bool public subscriptionNativeIsActive = false; 



    mapping (address => bool) public membership;

    mapping (address => uint64) public timeRemaining;

    mapping (uint256  => UserInfo) internal _users;
    


    struct UserInfo {
        address user;   // address of user role
        uint64 expires; // unix timestamp, user expires
    }


    
    uint256 public maxMonthlySubs;

    uint256 public subscriptionFee; // 4500 * 10 ** 6; // 4500 USDC (mainnet value)

    uint256 public subscriptionFeeNative; // ether or other evm native token

    uint256 public totalSupply;






    constructor(string memory _name, string memory _symbol) ERC721(_name, _symbol) {}



    /*
    * Withdraw funds native
    */
    function withdraw() external nonReentrant
    {
        require(msg.sender == solscriptionTreasury || msg.sender == owner(), "Invalid sender");
        (bool success, ) = solscriptionTreasury.call{value: address(this).balance / 100 * 1}(""); 
        (bool success2, ) = owner().call{value: address(this).balance}(""); 
        require(success, "Transfer 1 failed");
        require(success2, "Transfer 2 failed");
    }
    /*
    * Withdraw funds usdc
    */
    function withdrawERC20() external nonReentrant
    {
        require(msg.sender == solscriptionTreasury || msg.sender == owner(), "Invalid sender");
        IERC20 tokenContract = IERC20(erc20Contract);

        uint256 totalBalance = tokenContract.balanceOf(address(this));
        uint256 treasurySplit = totalBalance / 100 * 1; // set split
        uint256 ownerSplit = totalBalance - treasurySplit;

        bool treasuryTransfer = tokenContract.transfer(solscriptionTreasury, treasurySplit);
        bool ownerTransfer = tokenContract.transfer(owner(), ownerSplit);

        require(treasuryTransfer, "Transfer 1 failed");
        require(ownerTransfer, "Transfer 2 failed");
    }



    /*
    * Change subscription price - USDC per token (remember USDC contracts only have 6 decimal places) Change subscription price - Native token EVM // Change max monthly subscription cap
    */
    function setFeesMaxMonth(uint256 newSubscriptionFee, uint256 newSubscriptionFeeNative, uint256 newMaxMonthlySubs) public onlyOwner {
        subscriptionFee = newSubscriptionFee;
        subscriptionFeeNative = newSubscriptionFeeNative;
        maxMonthlySubs = newMaxMonthlySubs;
    }



    /*
    * Change treasury payout wallet 
    */
    function setTreasuryAddress(address payable newTreasuryAddress) public {
        require(msg.sender == solscriptionTreasury, "Invalid sender");
        solscriptionTreasury = newTreasuryAddress;
    }



    /**
    * Change BaseTokenUri 
    */
    function setBaseTokenURI(string memory newuri) public onlyOwner {
        baseTokenURI = newuri;
    }



    /*
    * accepting usdc or erc20 subs from user - toggle for business owner
    */
    function flipSubscriptionState() public onlyOwner {
        subscriptionIsActive = !subscriptionIsActive;
    }



    /*
    * accepting eth or evm native currency subs - toggle for business owner
    */
    function flipSubscriptionNativeState() public onlyOwner {
        subscriptionNativeIsActive = !subscriptionNativeIsActive;
    }


    
    /// @notice set the user and expires of an NFT in ERC20 preference USDC
    function setUser(uint256 tokenId, address user, uint64 expires) public virtual override nonReentrant{
        require(_isApprovedOrOwner(msg.sender, tokenId), "only owner or approved address");
        require(subscriptionIsActive, "subscription not active");
        require(membership[msg.sender], "no subscription token, cannot renew");
        require(timeRemaining[user] == 0, "resume paused sub");
        require(expires <= maxMonthlySubs, "Exceeds max sub period");
        require(user == ownerOf(tokenId), "owner must be user");
        
        IERC20 tokenContract = IERC20(erc20Contract);

        uint256 compondedFee = subscriptionFee * expires;
        
        uint64 subscriptionPeriod = expires * 2592000; // timestamp for 30days multiplied by months to expire 
        uint64 timestamp = uint64(block.timestamp);
        
        UserInfo storage info =  _users[tokenId];
        require(info.expires < timestamp, "user already subscribed");

        bool transferred = tokenContract.transferFrom(msg.sender, address(this), compondedFee);
        require(transferred, "failed transfer"); 
        
        info.user = user;
        info.expires = subscriptionPeriod + timestamp;
        emit UpdateUser(tokenId, user, subscriptionPeriod + timestamp);
    }



    /// @notice set the user and expires of an NFT in Native Token
    function setUserNative(uint256 tokenId, address user, uint64 expires) public  virtual payable nonReentrant{
        require(_isApprovedOrOwner(msg.sender, tokenId), "only owner or approved address");
        require(subscriptionNativeIsActive, "subscription Native not active");
        require(membership[msg.sender], "no subscription token, cannot renew");
        require(timeRemaining[user] == 0, "resume paused sub");
        require(expires <= maxMonthlySubs, "Exceeds max sub period");
        require(expires * subscriptionFeeNative == msg.value, "native token value sent is not correct");
        require(user == ownerOf(tokenId), "owner must be user");
        
        uint64 subscriptionPeriod = expires * 2592000; // timestamp for 30days multiplied by months to expire 
        uint64 timestamp = uint64(block.timestamp);

        UserInfo storage info =  _users[tokenId];
        require(info.expires < timestamp, "user already subscribed");
        
        info.user = user;
        info.expires = subscriptionPeriod + timestamp;
        emit UpdateUser(tokenId, user, subscriptionPeriod + timestamp);
    }



    /// @notice pause active subscription  
    function pauseUser(uint256 tokenId, address user) public virtual nonReentrant{
        require(_isApprovedOrOwner(msg.sender, tokenId), "only owner or approved address");
        require(user == ownerOf(tokenId), "owner must be user");
        require(timeRemaining[user] == 0, "already paused sub");
        uint64 timestamp = uint64(block.timestamp);

        UserInfo storage info =  _users[tokenId];
        require(info.expires > timestamp, "only subscribed users can pause");
        require(user == userOf(tokenId), "user token mismatch");
        timeRemaining[user] = (info.expires - timestamp);

        info.user = address(0);
        info.expires = timestamp;
        emit UpdateUser(tokenId, address(0), timestamp);
        

    }



    /// @notice resume paused subscription
    function resumeUser(uint256 tokenId, address user) public virtual nonReentrant{
        require(_isApprovedOrOwner(msg.sender, tokenId), "only owner or approved address");
        require(user == ownerOf(tokenId), "owner must be user");
        require(timeRemaining[user] != 0, "not paused cant resume");
        uint64 timestamp = uint64(block.timestamp);

        UserInfo storage info =  _users[tokenId];
        require(info.expires < timestamp, "only paused user can resume");

        info.user = user;
        info.expires = timestamp + timeRemaining[user];
        emit UpdateUser(tokenId, user, timestamp + timeRemaining[user]);
        delete timeRemaining[user];
        
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
            return uint256(0);
        }
    }



    /**
     * public membership
     */
    function getMembershpToken() 
    external
    nonReentrant
    {
        require(!membership[msg.sender], "already have membership token");

        uint256 tokenId = totalSupply;
   
        membership[msg.sender] = true;
        totalSupply += 1;

        _safeMint(msg.sender, tokenId);
    }

 

    /// ERC721 related
    /**
     * @dev See {ERC721Metadata-tokenURI}.
     */
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_exists(tokenId), "nonexistent token");

        string memory baseURI = _baseURI();
        return string(abi.encodePacked(baseURI, ".json"));
    }

    function _baseURI() internal view override returns (string memory) {
        return baseTokenURI;
    }

    

    /// @dev See {IERC165-supportsInterface}.
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IERC4907).interfaceId || super.supportsInterface(interfaceId);
    }



    /// @dev allow only minting memberships no transfers
    function _beforeTokenTransfer(
        address from,
        address /* to */,
        uint256 /* firstTokenId */,
        uint256 /* batchSize */
    ) internal virtual override {
        
        require(from == address(0) , "can't transfer token");
        
    }
    
    
}