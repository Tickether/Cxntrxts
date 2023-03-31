//SPDX-License-Identifier: MIT
// Code by @0xGeeLoko

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Burnable.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155URIStorage.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract MyToken is ERC1155, ERC1155Supply, ERC1155URIStorage, Ownable, ERC1155Burnable {
    AggregatorV3Interface internal priceFeed;
    
    mapping (uint256 => uint256) public price;

    uint256 public shippingFee;
    uint256 public productInventory;
    
    string public name;
    string public symbol;

    constructor() ERC1155("") {
        name = "dCommerce";
        symbol = "dC";

        /**
        * Network: Sepolia
        * Aggregator: ETH/USD
        * Address: 0x694AA1769357215DE4FAC081bf1f309aDC325306
        * Decimals: 8
        */
        priceFeed = AggregatorV3Interface(
            0x694AA1769357215DE4FAC081bf1f309aDC325306 // replace with usd and native chain token pair
        );
    }

    function setPrice(uint256 newPrice, uint256 id) 
        public 
        onlyOwner 
    {
        price[id] = newPrice;
    }

    function setShipping(uint256 newShippingFee) 
        public 
        onlyOwner 
    {
        shippingFee = newShippingFee;
    }

    /**
     * Returns the latest price.
     */
    function getLatestPrice(uint256 id) 
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
        return 1000000000000000000/(etherPrice/int(price[id]));
    }

    function ownerInitProduct(string memory _uri, uint256 _price) 
        public 
        onlyOwner 
    {
        uint256 id = productInventory;
        require(!exists(id), "product initilized");

        productInventory += 1;
        
        _mint(msg.sender, id, 1, "");
        _setURI(id, _uri);
        price[id] = _price;
    }

    function updateProductURI(uint256 id, string memory newuri) 
        public 
        onlyOwner 
    {
        _setURI(id, newuri);
    }

   
    function buy(address account, uint256 id, uint256 amount)
        public
        payable        
    {
        require(exists(id), "product not initilized");
        require (price[id] != 0, "product not active");

        uint256 latestPrice = uint256(getLatestPrice(id));
        require ((amount * latestPrice) + shippingFee == msg.value, "price not correct");
        
        _mint(account, id, amount, "");
    }

    function buyBulk(address to, uint256[] memory ids, uint256[] memory amounts)
        public
        payable
    {
        for (uint i = 0; i < ids.length; i++) {
            require(exists(ids[i]), "product not initilized");
            require (price[ids[i]] != 0, "product not active");

            uint256 latestPrice = uint256(getLatestPrice(ids[i]));
            require ((amounts[i] * latestPrice) + shippingFee == msg.value, "price not correct");
        }
        _mintBatch(to, ids, amounts, "");
    }

    /**
    * @notice returns the metadata uri for a given id
    *
    * @param _id the card id to return metadata for
    */
    function uri(uint256 _id) 
        public 
        view 
        override(ERC1155, ERC1155URIStorage) 
        returns (string memory)
    {
            require(exists(_id), "URI: nonexistent token");

            return string(abi.encodePacked(super.uri(_id)));
    }

    // The following functions are overrides required by Solidity.
    function _beforeTokenTransfer(address operator, address from, address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data)
        internal
        override(ERC1155, ERC1155Supply)
    {
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
        require(from == address(0) , "can't transfer token");
    }
}
