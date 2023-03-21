//SPDX-License-Identifier: MIT
//Code by @0xGeeLoko



pragma solidity ^0.8.9;



import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./IERC4907.sol";


contract MetaEstateRents is ERC721, ERC721URIStorage, IERC4907, Ownable, ReentrancyGuard {
    using Strings for string;



    address public erc20Contract; // USDC on evm mainnet



    bool public rentIsActive = false;

    bool public rentNativeIsActive = false;


    

    
    uint256 public maxMonthlyRent;

    uint256 public rentFee; // 4500 * 10 ** 6; // 4500 USDC (mainnet value)

    uint256 public rentFeeNative; // ether or other evm native token

    uint256 public totalSupply;




    address payable public treasury = payable(0x7ea9114092eC4379FFdf51bA6B72C71265F33e96);


   

    mapping (uint256  => UserInfo) internal _users;


    
    struct UserInfo {
        address user;   // address of user role
        uint64 expires; // unix timestamp, user expires
    }



    constructor( string memory _name, string memory _symbol) ERC721(_name, _symbol) {}



    /*
    * Withdraw funds
    */
    function withdraw() external nonReentrant
    {
        require(msg.sender == treasury || msg.sender == owner(), "Invalid sender");
        (bool success, ) = treasury.call{value: address(this).balance / 100 * 1}(""); 
        (bool success2, ) = owner().call{value: address(this).balance}(""); 
        require(success, "Transfer 1 failed");
        require(success2, "Transfer 2 failed");
    }

    function withdrawERC20() external nonReentrant
    {
        require(msg.sender == treasury || msg.sender == owner(), "Invalid sender");
        IERC20 tokenContract = IERC20(erc20Contract);

        uint256 totalBalance = tokenContract.balanceOf(address(this));
        uint256 treasurySplit = totalBalance / 100 * 1; // set split
        uint256 ownerSplit = totalBalance - treasurySplit;

        bool treasuryTransfer = tokenContract.transfer(treasury, treasurySplit);
        bool ownerTransfer = tokenContract.transfer(owner(), ownerSplit);

        require(treasuryTransfer, "Transfer 1 failed");
        require(ownerTransfer, "Transfer 2 failed");
    }



    /*
    * Change subscription price - USDC per token (remember USDC contracts only have 6 decimal places) Change subscription price - Native token EVM // Change max monthly subscription cap
    */
    function setFeesMaxMonth(uint256 newRentFee, uint256 newRentFeeNative, uint256 newMaxMonthlyRent) public onlyOwner {
        rentFee = newRentFee;
        rentFeeNative = newRentFeeNative;
        maxMonthlyRent = newMaxMonthlyRent;
    }



    /*   
    function setSubscriptionFeeNative(uint256 newSubscriptionFeeNative) public onlyOwner {
        subscriptionFeeNative = newSubscriptionFeeNative;
    }
    function setMaxMonthlySubs(uint256 newMaxMonthlySubs) public onlyOwner {
        maxMonthlySubs = newMaxMonthlySubs;
    }
    */



    /*
    * Change treasury payout wallet 
    */
    function setTreasuryAddress(address payable newTreasuryAddress) public {
        require(msg.sender == treasury, "Invalid sender");
        treasury = newTreasuryAddress;
    }

    /*
    * Change erc20 //usdt or usdc contract 
    */
    function setUSDAddress(address payable newUSDAddress) public onlyOwner{
        erc20Contract = newUSDAddress;
    }





    
    /// @notice set the user and expires of an NFT in ERC20 preference USDC
    /// @dev The zero address indicates there is no user
    /// Throws if `tokenId` is not valid NFT
    /// @param user  The new user of the NFT
    /// @param expires  UNIX timestamp, The new user could use the NFT before expires
    function setUser(uint256 tokenId, address user, uint64 expires) public virtual override{
        require(expires <= maxMonthlyRent, "Exceeds max sub period"); 
        require(ownerOf(tokenId) == owner(), "property sold, can't rent");
        require(erc20Contract != address(0), "erc20 token not set!");
        
        IERC20 tokenContract = IERC20(erc20Contract);

        uint256 compondedFee = rentFee * expires;
        
        bool transferred = tokenContract.transferFrom(msg.sender, address(this), compondedFee);
        require(transferred, "failed transfer");   

        
        uint64 rentPeriod = expires * 2592000; // timestamp for 30days multiplied by months to expire 
        uint64 timestamp = uint64(block.timestamp);
        
        UserInfo storage info =  _users[tokenId];
        require(info.expires < timestamp, "already rented");
        
        info.user = user;
        info.expires = rentPeriod + timestamp;
        emit UpdateUser(tokenId, user, rentPeriod + timestamp);
    }



    /// @notice set the user and expires of an NFT in Native Token
    /// @dev The zero address indicates there is no user
    /// Throws if `tokenId` is not valid NFT
    /// @param user  The new user of the NFT
    /// @param expires  UNIX timestamp, The new user could use the NFT before expires
    function setUserNative(uint256 tokenId, address user, uint64 expires) public  virtual payable {
        require(expires <= maxMonthlyRent, "Exceeds max sub period");
        require(expires * rentFeeNative == msg.value, 'native token value sent is not correct');
        require(ownerOf(tokenId) == owner(), "property sold, can't rent");
        
        uint64 rentPeriod = expires * 2592000; // timestamp for 30days multiplied by months to expire 
        uint64 timestamp = uint64(block.timestamp);

        UserInfo storage info =  _users[tokenId];
        require(info.expires < timestamp, "already rented");
        
        info.user = user;
        info.expires = rentPeriod + timestamp;
        emit UpdateUser(tokenId, user, rentPeriod + timestamp);
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
     * public subscription
     */
    function makeMetaEstateToken(string memory _tokenURI) 
    external
    nonReentrant
    onlyOwner
    {
        require(msg.sender == tx.origin, "No contract transactions!");
       
        uint256 tokenId = totalSupply;


        _safeMint(msg.sender, tokenId);
        _setTokenURI(tokenId, _tokenURI);
        
        totalSupply += 1;
        
        
    }

    /** 
     *  
    */



    /// ERC721 related
    /**
     * @dev See {ERC721Metadata-tokenURI}.
     */
    // The following functions are overrides required by Solidity.

    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }
    

    

    /// @dev See {IERC165-supportsInterface}.
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IERC4907).interfaceId || super.supportsInterface(interfaceId);
    }

    
    function _beforeTokenTransfer(
        address from,
        address /* to */,
        uint256 firstTokenId,
        uint256 /* batchSize */
    ) internal virtual override {

        if(from != address(0)) {
            require(_users[firstTokenId].user == address(0), "can't sell or tranfer rented property");
    
            delete _users[firstTokenId];
            emit UpdateUser(firstTokenId, address(0), 0);

        }

       

    }

   

}