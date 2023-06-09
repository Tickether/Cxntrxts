//SPDX-License-Identifier: MIT
//Code by @0xGeeLoko



pragma solidity ^0.8.9;


import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./IERC4907.sol";

contract Solscription is ERC721, IERC4907, Ownable, ReentrancyGuard {
    AggregatorV3Interface internal priceFeed;
    using Strings for string;

    bool public subscriptionIsActive = false;
    bool public membershipIsActive = false;

    uint256 public maxMonthlySubs;
    uint256 public subscriptionFee; // 4500 * 10 ** 8; // 4500 USDC (chainlink value)
    uint256 public totalMembers;

    string public baseTokenURI;


    struct UserInfo 
    {
        address user;   // address of user role
        uint64 expires; // unix timestamp, user expires
    }

    event Attest(address indexed to, uint256 indexed tokenId);
    event Revoke(address indexed to, uint256 indexed tokenId);

    mapping (address => bool) public membership;
    mapping (uint256  => UserInfo) internal _users;

    constructor() ERC721("SmokleyS Lounge", "SSL") {

        /**
        * Network: Sepolia
        * Aggregator: ETH/USD
        * Address: 0x694AA1769357215DE4FAC081bf1f309aDC325306
        * Decimals: 8
        */

        /**
        * Network: Goerli
        * Aggregator: ETH/USD
        * Address: 0xD4a33860578De61DBAbDc8BFdb98FD742fA7028e
        * Decimals: 8
        */

        priceFeed = AggregatorV3Interface(
            0xD4a33860578De61DBAbDc8BFdb98FD742fA7028e // replace with usd and native chain token pair
        );
    }


    /*
    * Withdraw funds
    */
    function withdraw() 
        external 
        onlyOwner 
        nonReentrant
    {
        (bool success, ) = owner().call{value: address(this).balance}(""); 
        require(success, "Transfer failed");
    }

    function withdrawERC20(address erc20Contract) 
        external 
        onlyOwner
        nonReentrant
    {
        IERC20 tokenContract = IERC20(erc20Contract);

        uint256 totalBalance = tokenContract.balanceOf(address(this));
        
        bool ownerTransfer = tokenContract.transfer(owner(), totalBalance);

        require(ownerTransfer, "Transfer failed");
    }
    

    /*
    * Change subscription price // Change max monthly subscription cap
    */
    function setFeesMaxMonth(uint256 newSubscriptionFee,  uint256 newMaxMonthlySubs) 
        public 
        onlyOwner 
    {
        subscriptionFee = newSubscriptionFee;
        maxMonthlySubs = newMaxMonthlySubs;
    }

    /**
    * Change BaseTokenUri 
    */
    function setBaseTokenURI(string memory newuri) 
        public 
        onlyOwner 
    {
        baseTokenURI = newuri;
    }

    
    /*
    * Pause subs if active, make active if paused
    */
    function flipSubscriptionState() 
        public 
        onlyOwner 
    {
        subscriptionIsActive = !subscriptionIsActive;
    }



    /*
    * Pause membership mint if active, make active if paused
    */
    function flipMembershipState() 
        public 
        onlyOwner 
    {
        membershipIsActive = !membershipIsActive;
    }


    /**
     * Returns the latest price.
     */
    function getLatestPrice() 
        public 
        view 
        returns (int) 
    
    {
        // prettier-ignore
        (
            /* uint80 roundID */,
            int etherPrice,
            /*uint startedAt*/,
            /*uint timeStamp*/,
            /*uint80 answeredInRound*/
        ) = priceFeed.latestRoundData();
        return 1000000000000000000/(etherPrice/int(subscriptionFee));
    }


    /**
     * public membership
     */
    function getMembersToken() 
        external
        nonReentrant
    {
        require(msg.sender == tx.origin, "No contract transactions!");
        require(membershipIsActive, "membership closed");
        require(!membership[msg.sender], "already have subscription token");

        uint256 tokenId = totalMembers;


        _safeMint(msg.sender, tokenId);
        
        totalMembers += 1;
        membership[msg.sender] = true;

        
    }

    


    /// @notice set the user and expires of an NFT
    /// @dev The zero address indicates there is no user
    /// Throws if `tokenId` is not valid NFT
    /// @param user  The new user of the NFT
    /// @param expires  UNIX timestamp, The new user could use the NFT before expires
    function setUser(uint256 tokenId, address user, uint64 expires) 
        public 
        payable 
        virtual
        nonReentrant
    {
        require(_isApprovedOrOwner(msg.sender, tokenId), "yo! Cant do that shit lol");
        require(subscriptionIsActive, "subscription not active");
        require(membership[msg.sender], "not a member, cannot renew");
        require(expires <= maxMonthlySubs, "Exceeds max sub period");

        uint256 latestPrice = uint256(getLatestPrice());
        require(expires * latestPrice == msg.value, "value sent is not correct");
        
        uint64 subscriptionPeriod = expires * 2592000; // timestamp for 30days multiplied by months to expire 
        uint64 timestamp = uint64(block.timestamp);

        UserInfo storage info =  _users[tokenId];
        require(info.expires < timestamp, "user already subscribed");
        
        info.user = user;
        info.expires = subscriptionPeriod + timestamp;
        emit UpdateUser(tokenId, user, subscriptionPeriod + timestamp);
    }

    /// @notice Get the user address of an NFT
    /// @dev The zero address indicates that there is no user or the user is expired
    /// @param tokenId The NFT to get the user address for
    /// @return The user address for this NFT
    function userOf(uint256 tokenId) 
        public 
        view 
        virtual 
        returns(address)
    {
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
    function userExpires(uint256 tokenId) 
        public 
        view 
        virtual 
        returns(uint256)
    {
        return _users[tokenId].expires;
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


    /// @dev See {IERC165-supportsInterface}.
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IERC4907).interfaceId || super.supportsInterface(interfaceId);
    }

    function revoke(uint256 tokenId) 
        external 
    {
        _burn(tokenId);
        membership[msg.sender] = false;
    }



    function _beforeTokenTransfer(
        address from,
        address to,
        uint256, /* firstTokenId */
        uint256 /* batchSize */
    ) internal virtual override {
        
        require(from == address(0) || to == address(0), "can't transfer token");
        
    }

    function _afterTokenTransfer(
        address from,
        address to,
        uint256 firstTokenId,
        uint256 /* batchSize */
    ) internal virtual override  {
        if (from == address(0)) {
            emit Attest(to, firstTokenId);
        } else if (to == address(0)) {
            emit Revoke(to, firstTokenId);
        }
    }

}
