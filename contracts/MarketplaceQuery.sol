// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

/**
 * @title MarketplaceQuery
 * @dev Provides efficient query capabilities for the BAN NFT Marketplace
 * This contract serves as a data access layer for frontend applications
 */
contract MarketplaceQuery is Ownable, Pausable {
    mapping(address => bool) public authorizedContracts;

    struct AuctionData {
        uint256 auctionId;
        address seller;
        address nftContract;
        uint256 tokenId;
        uint256 reservePrice;
        uint256 buyNowPrice;
        uint256 startTime;
        uint256 endTime;
        address highestBidder;
        uint256 highestBid;
        bool isSettled;
        uint8 status;
        uint256 royaltyPercentage;
        uint8 assetType;
        uint256 createdAt;
    }

    struct ListingData {
        uint256 listingId;
        address seller;
        address nftContract;
        uint256 tokenId;
        uint256 price;
        bool isActive;
        uint8 assetType;
        uint256 royaltyPercentage;
        uint256 createdAt;
    }

    struct BidData {
        address bidder;
        uint256 amount;
        uint256 timestamp;
    }

    struct NFTData {
        address nftContract;
        uint256 tokenId;
        address creator;
        address owner;
        string tokenURI;
        uint256 royaltyPercentage;
        uint8 assetType;
        bool isListed;
        bool isInAuction;
        uint256 listingId;
        uint256 auctionId;
    }

    AuctionData[] private auctions;
    ListingData[] private listings;

    mapping(address => uint256[]) private userAuctions;
    mapping(address => uint256[]) private userBids;
    mapping(address => uint256[]) private userListings;
    mapping(address => uint256[]) private userPurchases;

    mapping(address => mapping(uint256 => NFTData)) private nftData;
    mapping(address => uint256[]) private creatorNFTs;

    mapping(bytes32 => uint256[]) private auctionsByCategory;
    mapping(bytes32 => uint256[]) private listingsByCategory;

    mapping(uint256 => uint256[]) private auctionsByPriceRange;
    mapping(uint256 => uint256[]) private listingsByPriceRange;

    event AuctionIndexed(
        uint256 indexed auctionId,
        address indexed seller,
        address indexed nftContract,
        uint256 tokenId
    );
    event ListingIndexed(
        uint256 indexed listingId,
        address indexed seller,
        address indexed nftContract,
        uint256 tokenId
    );
    event NFTDataUpdated(
        address indexed nftContract,
        uint256 indexed tokenId,
        address owner
    );
    event AuthorizedContractAdded(address indexed contractAddress);
    event AuthorizedContractRemoved(address indexed contractAddress);

    /**
     * @dev Modifier that only allows authorized contracts to call functions
     */
    modifier onlyAuthorized() {
        require(authorizedContracts[msg.sender], "Caller is not authorized");
        _;
    }

    /**
     * @dev Constructor initializes the contract
     */
    constructor() {}

    /**
     * @dev Add a contract to the authorized list
     * @param _contract Address of the contract to authorize
     */
    function addAuthorizedContract(address _contract) external onlyOwner {
        require(_contract != address(0), "Invalid contract address");
        authorizedContracts[_contract] = true;
        emit AuthorizedContractAdded(_contract);
    }

    /**
     * @dev Remove a contract from the authorized list
     * @param _contract Address of the contract to remove
     */
    function removeAuthorizedContract(address _contract) external onlyOwner {
        authorizedContracts[_contract] = false;
        emit AuthorizedContractRemoved(_contract);
    }

    /**
     * @dev Pause the contract
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @dev Unpause the contract
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    /**
     * @dev Record a new auction
     * @param _auctionId Auction ID
     * @param _seller Seller address
     * @param _nftContract NFT contract address
     * @param _tokenId Token ID
     * @param _reservePrice Reserve price
     * @param _buyNowPrice Buy now price
     * @param _startTime Start time
     * @param _endTime End time
     * @param _royaltyPercentage Royalty percentage
     * @param _assetType Asset type (0: NFT, 1: RWA)
     * @param _category Category
     */
    function recordAuction(
        uint256 _auctionId,
        address _seller,
        address _nftContract,
        uint256 _tokenId,
        uint256 _reservePrice,
        uint256 _buyNowPrice,
        uint256 _startTime,
        uint256 _endTime,
        uint256 _royaltyPercentage,
        uint8 _assetType,
        bytes32 _category
    ) external onlyAuthorized whenNotPaused {
        AuctionData memory auctionData = AuctionData({
            auctionId: _auctionId,
            seller: _seller,
            nftContract: _nftContract,
            tokenId: _tokenId,
            reservePrice: _reservePrice,
            buyNowPrice: _buyNowPrice,
            startTime: _startTime,
            endTime: _endTime,
            highestBidder: address(0),
            highestBid: 0,
            isSettled: false,
            status: 0,
            royaltyPercentage: _royaltyPercentage,
            assetType: _assetType,
            createdAt: block.timestamp
        });

        if (_auctionId >= auctions.length) {
            auctions.push(auctionData);
        } else {
            auctions[_auctionId] = auctionData;
        }

        userAuctions[_seller].push(_auctionId);

        if (_category != bytes32(0)) {
            auctionsByCategory[_category].push(_auctionId);
        }

        uint256 priceRangeId = _getPriceRangeId(_reservePrice);
        auctionsByPriceRange[priceRangeId].push(_auctionId);

        _updateNFTAuctionStatus(_nftContract, _tokenId, _auctionId, true);

        emit AuctionIndexed(_auctionId, _seller, _nftContract, _tokenId);
    }

    /**
     * @dev Record a bid on an auction
     * @param _auctionId Auction ID
     * @param _bidder Bidder address
     * @param _bidAmount Bid amount
     */
    function recordBid(
        uint256 _auctionId,
        address _bidder,
        uint256 _bidAmount
    ) external onlyAuthorized whenNotPaused {
        require(_auctionId < auctions.length, "Auction does not exist");

        AuctionData storage auction = auctions[_auctionId];
        auction.highestBidder = _bidder;
        auction.highestBid = _bidAmount;

        if (!_contains(userBids[_bidder], _auctionId)) {
            userBids[_bidder].push(_auctionId);
        }
    }

    /**
     * @dev Record an auction as settled
     * @param _auctionId Auction ID
     * @param _winner Winner address
     */
    function recordAuctionSettled(
        uint256 _auctionId,
        address _winner
    ) external onlyAuthorized whenNotPaused {
        require(_auctionId < auctions.length, "Auction does not exist");

        AuctionData storage auction = auctions[_auctionId];
        auction.isSettled = true;
        auction.status = 1;
        auction.highestBidder = _winner;

        _updateNFTAuctionStatus(auction.nftContract, auction.tokenId, 0, false);
        _updateNFTOwner(auction.nftContract, auction.tokenId, _winner);
    }

    /**
     * @dev Record a listing
     * @param _listingId Listing ID
     * @param _seller Seller address
     * @param _nftContract NFT contract address
     * @param _tokenId Token ID
     * @param _price Price
     * @param _assetType Asset type (0: NFT, 1: RWA)
     * @param _royaltyPercentage Royalty percentage
     * @param _category Category
     */
    function recordListing(
        uint256 _listingId,
        address _seller,
        address _nftContract,
        uint256 _tokenId,
        uint256 _price,
        uint8 _assetType,
        uint256 _royaltyPercentage,
        bytes32 _category
    ) external onlyAuthorized whenNotPaused {
        ListingData memory listingData = ListingData({
            listingId: _listingId,
            seller: _seller,
            nftContract: _nftContract,
            tokenId: _tokenId,
            price: _price,
            isActive: true,
            assetType: _assetType,
            royaltyPercentage: _royaltyPercentage,
            createdAt: block.timestamp
        });

        if (_listingId >= listings.length) {
            listings.push(listingData);
        } else {
            listings[_listingId] = listingData;
        }

        userListings[_seller].push(_listingId);

        if (_category != bytes32(0)) {
            listingsByCategory[_category].push(_listingId);
        }

        uint256 priceRangeId = _getPriceRangeId(_price);
        listingsByPriceRange[priceRangeId].push(_listingId);

        _updateNFTListingStatus(_nftContract, _tokenId, _listingId, true);

        emit ListingIndexed(_listingId, _seller, _nftContract, _tokenId);
    }

    /**
     * @dev Record a listing purchase
     * @param _listingId Listing ID
     * @param _buyer Buyer address
     */
    function recordListingPurchased(
        uint256 _listingId,
        address _buyer
    ) external onlyAuthorized whenNotPaused {
        require(_listingId < listings.length, "Listing does not exist");

        ListingData storage listing = listings[_listingId];
        listing.isActive = false;

        userPurchases[_buyer].push(_listingId);

        _updateNFTListingStatus(listing.nftContract, listing.tokenId, 0, false);
        _updateNFTOwner(listing.nftContract, listing.tokenId, _buyer);
    }

    /**
     * @dev Record NFT data
     * @param _nftContract NFT contract address
     * @param _tokenId Token ID
     * @param _creator Creator address
     * @param _owner Owner address
     * @param _tokenURI Token URI
     * @param _royaltyPercentage Royalty percentage
     * @param _assetType Asset type (0: NFT, 1: RWA)
     */
    function recordNFTData(
        address _nftContract,
        uint256 _tokenId,
        address _creator,
        address _owner,
        string calldata _tokenURI,
        uint256 _royaltyPercentage,
        uint8 _assetType
    ) external onlyAuthorized whenNotPaused {
        NFTData storage data = nftData[_nftContract][_tokenId];

        if (data.nftContract == address(0)) {
            data.nftContract = _nftContract;
            data.tokenId = _tokenId;
            data.creator = _creator;
            data.isListed = false;
            data.isInAuction = false;

            creatorNFTs[_creator].push(_tokenId);
        }

        data.owner = _owner;
        data.tokenURI = _tokenURI;
        data.royaltyPercentage = _royaltyPercentage;
        data.assetType = _assetType;

        emit NFTDataUpdated(_nftContract, _tokenId, _owner);
    }

    /**
     * @dev Record auction canceled
     * @param _auctionId Auction ID
     */
    function recordAuctionCanceled(
        uint256 _auctionId
    ) external onlyAuthorized whenNotPaused {
        require(_auctionId < auctions.length, "Auction does not exist");

        AuctionData storage auction = auctions[_auctionId];
        auction.status = 2;
        auction.isSettled = true;

        _updateNFTAuctionStatus(auction.nftContract, auction.tokenId, 0, false);
    }

    /**
     * @dev Record listing canceled
     * @param _listingId Listing ID
     */
    function recordListingCanceled(
        uint256 _listingId
    ) external onlyAuthorized whenNotPaused {
        require(_listingId < listings.length, "Listing does not exist");

        ListingData storage listing = listings[_listingId];
        listing.isActive = false;

        _updateNFTListingStatus(listing.nftContract, listing.tokenId, 0, false);
    }

    /**
     * @dev Record listing updated (price change)
     * @param _listingId Listing ID
     * @param _newPrice New price
     */
    function recordListingUpdated(
        uint256 _listingId,
        uint256 _newPrice
    ) external onlyAuthorized whenNotPaused {
        require(_listingId < listings.length, "Listing does not exist");

        ListingData storage listing = listings[_listingId];
        uint256 oldPrice = listing.price;
        listing.price = _newPrice;

        uint256 oldPriceRange = _getPriceRangeId(oldPrice);
        uint256 newPriceRange = _getPriceRangeId(_newPrice);

        if (oldPriceRange != newPriceRange) {
            _updatePriceRangeIndex(
                _listingId,
                oldPriceRange,
                newPriceRange,
                false
            );
        }
    }

    /**
     * @dev Record auction updated (price changes)
     * @param _auctionId Auction ID
     * @param _newReservePrice New reserve price
     * @param _newBuyNowPrice New buy now price
     */
    function recordAuctionUpdated(
        uint256 _auctionId,
        uint256 _newReservePrice,
        uint256 _newBuyNowPrice
    ) external onlyAuthorized whenNotPaused {
        require(_auctionId < auctions.length, "Auction does not exist");

        AuctionData storage auction = auctions[_auctionId];
        uint256 oldReservePrice = auction.reservePrice;
        auction.reservePrice = _newReservePrice;
        auction.buyNowPrice = _newBuyNowPrice;

        uint256 oldPriceRange = _getPriceRangeId(oldReservePrice);
        uint256 newPriceRange = _getPriceRangeId(_newReservePrice);

        if (oldPriceRange != newPriceRange) {
            _updatePriceRangeIndex(
                _auctionId,
                oldPriceRange,
                newPriceRange,
                true
            );
        }
    }

    /**
     * @dev Get auctions for a specific user
     * @param _user User address
     * @param _start Start index
     * @param _limit Max items to return
     * @return Array of auction data
     */
    function getUserAuctions(
        address _user,
        uint256 _start,
        uint256 _limit
    ) external view returns (AuctionData[] memory) {
        uint256[] storage userAuctionIds = userAuctions[_user];

        uint256 count = userAuctionIds.length;
        if (count == 0) {
            return new AuctionData[](0);
        }

        uint256 end = _start + _limit;
        if (end > count) {
            end = count;
        }
        if (_start >= end) {
            return new AuctionData[](0);
        }

        AuctionData[] memory result = new AuctionData[](end - _start);
        for (uint256 i = _start; i < end; i++) {
            result[i - _start] = auctions[userAuctionIds[i]];
        }

        return result;
    }

    /**
     * @dev Get bids for a specific user
     * @param _user User address
     * @param _start Start index
     * @param _limit Max items to return
     * @return Array of auction data
     */
    function getUserBids(
        address _user,
        uint256 _start,
        uint256 _limit
    ) external view returns (AuctionData[] memory) {
        uint256[] storage userBidIds = userBids[_user];

        uint256 count = userBidIds.length;
        if (count == 0) {
            return new AuctionData[](0);
        }

        uint256 end = _start + _limit;
        if (end > count) {
            end = count;
        }
        if (_start >= end) {
            return new AuctionData[](0);
        }

        AuctionData[] memory result = new AuctionData[](end - _start);
        for (uint256 i = _start; i < end; i++) {
            result[i - _start] = auctions[userBidIds[i]];
        }

        return result;
    }

    /**
     * @dev Get listings for a specific user
     * @param _user User address
     * @param _start Start index
     * @param _limit Max items to return
     * @return Array of listing data
     */
    function getUserListings(
        address _user,
        uint256 _start,
        uint256 _limit
    ) external view returns (ListingData[] memory) {
        uint256[] storage userListingIds = userListings[_user];

        uint256 count = userListingIds.length;
        if (count == 0) {
            return new ListingData[](0);
        }

        uint256 end = _start + _limit;
        if (end > count) {
            end = count;
        }
        if (_start >= end) {
            return new ListingData[](0);
        }

        ListingData[] memory result = new ListingData[](end - _start);
        for (uint256 i = _start; i < end; i++) {
            result[i - _start] = listings[userListingIds[i]];
        }

        return result;
    }

    /**
     * @dev Get purchases for a specific user
     * @param _user User address
     * @param _start Start index
     * @param _limit Max items to return
     * @return Array of listing data
     */
    function getUserPurchases(
        address _user,
        uint256 _start,
        uint256 _limit
    ) external view returns (ListingData[] memory) {
        uint256[] storage userPurchaseIds = userPurchases[_user];

        uint256 count = userPurchaseIds.length;
        if (count == 0) {
            return new ListingData[](0);
        }

        uint256 end = _start + _limit;
        if (end > count) {
            end = count;
        }
        if (_start >= end) {
            return new ListingData[](0);
        }

        ListingData[] memory result = new ListingData[](end - _start);
        for (uint256 i = _start; i < end; i++) {
            result[i - _start] = listings[userPurchaseIds[i]];
        }

        return result;
    }

    /**
     * @dev Get auctions by category
     * @param _category Category
     * @param _start Start index
     * @param _limit Max items to return
     * @return Array of auction data
     */
    function getAuctionsByCategory(
        bytes32 _category,
        uint256 _start,
        uint256 _limit
    ) external view returns (AuctionData[] memory) {
        uint256[] storage categoryAuctionIds = auctionsByCategory[_category];

        uint256 count = categoryAuctionIds.length;
        if (count == 0) {
            return new AuctionData[](0);
        }

        uint256 end = _start + _limit;
        if (end > count) {
            end = count;
        }
        if (_start >= end) {
            return new AuctionData[](0);
        }

        AuctionData[] memory result = new AuctionData[](end - _start);
        for (uint256 i = _start; i < end; i++) {
            result[i - _start] = auctions[categoryAuctionIds[i]];
        }

        return result;
    }

    /**
     * @dev Get listings by category
     * @param _category Category
     * @param _start Start index
     * @param _limit Max items to return
     * @return Array of listing data
     */
    function getListingsByCategory(
        bytes32 _category,
        uint256 _start,
        uint256 _limit
    ) external view returns (ListingData[] memory) {
        uint256[] storage categoryListingIds = listingsByCategory[_category];

        uint256 count = categoryListingIds.length;
        if (count == 0) {
            return new ListingData[](0);
        }

        uint256 end = _start + _limit;
        if (end > count) {
            end = count;
        }
        if (_start >= end) {
            return new ListingData[](0);
        }

        ListingData[] memory result = new ListingData[](end - _start);
        for (uint256 i = _start; i < end; i++) {
            result[i - _start] = listings[categoryListingIds[i]];
        }

        return result;
    }

    /**
     * @dev Get all active auctions
     * @param _start Start index
     * @param _limit Max items to return
     * @return Array of auction data
     */
    function getActiveAuctions(
        uint256 _start,
        uint256 _limit
    ) external view returns (AuctionData[] memory) {
        uint256 activeCount = 0;
        for (uint256 i = 0; i < auctions.length; i++) {
            if (auctions[i].status == 0) {
                activeCount++;
            }
        }

        if (activeCount == 0) {
            return new AuctionData[](0);
        }

        uint256 end = _start + _limit;
        if (end > activeCount) {
            end = activeCount;
        }
        if (_start >= end) {
            return new AuctionData[](0);
        }

        AuctionData[] memory result = new AuctionData[](end - _start);
        uint256 resultIndex = 0;
        uint256 activeIndex = 0;

        for (
            uint256 i = 0;
            i < auctions.length && resultIndex < result.length;
            i++
        ) {
            if (auctions[i].status == 0) {
                if (activeIndex >= _start && activeIndex < end) {
                    result[resultIndex] = auctions[i];
                    resultIndex++;
                }
                activeIndex++;
            }
        }

        return result;
    }

    /**
     * @dev Get all active listings
     * @param _start Start index
     * @param _limit Max items to return
     * @return Array of listing data
     */
    function getActiveListings(
        uint256 _start,
        uint256 _limit
    ) external view returns (ListingData[] memory) {
        uint256 activeCount = 0;
        for (uint256 i = 0; i < listings.length; i++) {
            if (listings[i].isActive) {
                activeCount++;
            }
        }

        if (activeCount == 0) {
            return new ListingData[](0);
        }

        uint256 end = _start + _limit;
        if (end > activeCount) {
            end = activeCount;
        }
        if (_start >= end) {
            return new ListingData[](0);
        }

        ListingData[] memory result = new ListingData[](end - _start);
        uint256 resultIndex = 0;
        uint256 activeIndex = 0;

        for (
            uint256 i = 0;
            i < listings.length && resultIndex < result.length;
            i++
        ) {
            if (listings[i].isActive) {
                if (activeIndex >= _start && activeIndex < end) {
                    result[resultIndex] = listings[i];
                    resultIndex++;
                }
                activeIndex++;
            }
        }

        return result;
    }

    /**
     * @dev Get auction details
     * @param _auctionId Auction ID
     * @return Auction data
     */
    function getAuctionDetails(
        uint256 _auctionId
    ) external view returns (AuctionData memory) {
        require(_auctionId < auctions.length, "Auction does not exist");
        return auctions[_auctionId];
    }

    /**
     * @dev Get listing details
     * @param _listingId Listing ID
     * @return Listing data
     */
    function getListingDetails(
        uint256 _listingId
    ) external view returns (ListingData memory) {
        require(_listingId < listings.length, "Listing does not exist");
        return listings[_listingId];
    }

    /**
     * @dev Get NFT data
     * @param _nftContract NFT contract address
     * @param _tokenId Token ID
     * @return NFT data
     */
    function getNFTData(
        address _nftContract,
        uint256 _tokenId
    ) external view returns (NFTData memory) {
        return nftData[_nftContract][_tokenId];
    }

    /**
     * @dev Get creator NFTs
     * @param _creator Creator address
     * @param _start Start index
     * @param _limit Max items to return
     * @return Array of NFT data
     */
    function getCreatorNFTs(
        address _creator,
        uint256 _start,
        uint256 _limit
    ) external view returns (NFTData[] memory) {
        uint256[] storage creatorTokenIds = creatorNFTs[_creator];

        uint256 count = creatorTokenIds.length;
        if (count == 0) {
            return new NFTData[](0);
        }

        uint256 end = _start + _limit;
        if (end > count) {
            end = count;
        }
        if (_start >= end) {
            return new NFTData[](0);
        }

        address nftContract = address(0);
        if (count > 0) {
            for (uint256 i = 0; i < count; i++) {
                uint256 tokenId = creatorTokenIds[i];
                if (nftData[nftContract][tokenId].nftContract != address(0)) {
                    nftContract = nftData[nftContract][tokenId].nftContract;
                    break;
                }
            }
        }

        NFTData[] memory result = new NFTData[](end - _start);
        for (uint256 i = _start; i < end; i++) {
            result[i - _start] = nftData[nftContract][creatorTokenIds[i]];
        }

        return result;
    }

    /**
     * @dev Get bid history for an auction
     * @return Array of bid data
     */
    function getBidHistory(uint256) external pure returns (BidData[] memory) {
        return new BidData[](0);
    }

    /**
     * @dev Get auctions ending soon
     * @param _timeWindow Time window in seconds
     * @param _limit Max items to return
     * @return Array of auction data
     */
    function getAuctionsEndingSoon(
        uint256 _timeWindow,
        uint256 _limit
    ) external view returns (AuctionData[] memory) {
        uint256 currentTime = block.timestamp;
        uint256 endTime = currentTime + _timeWindow;

        uint256 eligibleCount = 0;
        for (uint256 i = 0; i < auctions.length; i++) {
            if (
                auctions[i].status == 0 &&
                auctions[i].endTime > currentTime &&
                auctions[i].endTime <= endTime
            ) {
                eligibleCount++;
            }
        }

        if (eligibleCount == 0) {
            return new AuctionData[](0);
        }

        uint256 resultCount = eligibleCount < _limit ? eligibleCount : _limit;

        AuctionData[] memory result = new AuctionData[](resultCount);
        uint256 resultIndex = 0;

        for (
            uint256 i = 0;
            i < auctions.length && resultIndex < resultCount;
            i++
        ) {
            if (
                auctions[i].status == 0 &&
                auctions[i].endTime > currentTime &&
                auctions[i].endTime <= endTime
            ) {
                result[resultIndex] = auctions[i];
                resultIndex++;
            }
        }

        return result;
    }

    /**
     * @dev Get recently created auctions
     * @param _timeWindow Time window in seconds
     * @param _limit Max items to return
     * @return Array of auction data
     */
    function getRecentlyCreatedAuctions(
        uint256 _timeWindow,
        uint256 _limit
    ) external view returns (AuctionData[] memory) {
        uint256 currentTime = block.timestamp;
        uint256 startTime = currentTime - _timeWindow;

        uint256 eligibleCount = 0;
        for (uint256 i = 0; i < auctions.length; i++) {
            if (auctions[i].status == 0 && auctions[i].createdAt >= startTime) {
                eligibleCount++;
            }
        }

        if (eligibleCount == 0) {
            return new AuctionData[](0);
        }

        uint256 resultCount = eligibleCount < _limit ? eligibleCount : _limit;

        AuctionData[] memory result = new AuctionData[](resultCount);
        uint256 resultIndex = 0;

        for (
            uint256 i = 0;
            i < auctions.length && resultIndex < resultCount;
            i++
        ) {
            if (auctions[i].status == 0 && auctions[i].createdAt >= startTime) {
                result[resultIndex] = auctions[i];
                resultIndex++;
            }
        }

        return result;
    }

    /**
     * @dev Get recently created listings
     * @param _timeWindow Time window in seconds
     * @param _limit Max items to return
     * @return Array of listing data
     */
    function getRecentlyCreatedListings(
        uint256 _timeWindow,
        uint256 _limit
    ) external view returns (ListingData[] memory) {
        uint256 currentTime = block.timestamp;
        uint256 startTime = currentTime - _timeWindow;

        uint256 eligibleCount = 0;
        for (uint256 i = 0; i < listings.length; i++) {
            if (listings[i].isActive && listings[i].createdAt >= startTime) {
                eligibleCount++;
            }
        }

        if (eligibleCount == 0) {
            return new ListingData[](0);
        }

        uint256 resultCount = eligibleCount < _limit ? eligibleCount : _limit;

        ListingData[] memory result = new ListingData[](resultCount);
        uint256 resultIndex = 0;

        for (
            uint256 i = 0;
            i < listings.length && resultIndex < resultCount;
            i++
        ) {
            if (listings[i].isActive && listings[i].createdAt >= startTime) {
                result[resultIndex] = listings[i];
                resultIndex++;
            }
        }

        return result;
    }

    /**
     * @dev Get listings by NFT contract
     * @param _nftContract NFT contract address
     * @param _start Start index
     * @param _limit Max items to return
     * @return Array of listing data
     */
    function getListingsByNFTContract(
        address _nftContract,
        uint256 _start,
        uint256 _limit
    ) external view returns (ListingData[] memory) {
        uint256 eligibleCount = 0;
        for (uint256 i = 0; i < listings.length; i++) {
            if (
                listings[i].isActive && listings[i].nftContract == _nftContract
            ) {
                eligibleCount++;
            }
        }

        if (eligibleCount == 0) {
            return new ListingData[](0);
        }

        uint256 end = _start + _limit;
        if (end > eligibleCount) {
            end = eligibleCount;
        }
        if (_start >= end) {
            return new ListingData[](0);
        }

        ListingData[] memory result = new ListingData[](end - _start);
        uint256 resultIndex = 0;
        uint256 eligibleIndex = 0;

        for (
            uint256 i = 0;
            i < listings.length && resultIndex < result.length;
            i++
        ) {
            if (
                listings[i].isActive && listings[i].nftContract == _nftContract
            ) {
                if (eligibleIndex >= _start && eligibleIndex < end) {
                    result[resultIndex] = listings[i];
                    resultIndex++;
                }
                eligibleIndex++;
            }
        }

        return result;
    }

    /**
     * @dev Get auctions by NFT contract
     * @param _nftContract NFT contract address
     * @param _start Start index
     * @param _limit Max items to return
     * @return Array of auction data
     */
    function getAuctionsByNFTContract(
        address _nftContract,
        uint256 _start,
        uint256 _limit
    ) external view returns (AuctionData[] memory) {
        uint256 eligibleCount = 0;
        for (uint256 i = 0; i < auctions.length; i++) {
            if (
                auctions[i].status == 0 &&
                auctions[i].nftContract == _nftContract
            ) {
                eligibleCount++;
            }
        }

        if (eligibleCount == 0) {
            return new AuctionData[](0);
        }

        uint256 end = _start + _limit;
        if (end > eligibleCount) {
            end = eligibleCount;
        }
        if (_start >= end) {
            return new AuctionData[](0);
        }

        AuctionData[] memory result = new AuctionData[](end - _start);
        uint256 resultIndex = 0;
        uint256 eligibleIndex = 0;

        for (
            uint256 i = 0;
            i < auctions.length && resultIndex < result.length;
            i++
        ) {
            if (
                auctions[i].status == 0 &&
                auctions[i].nftContract == _nftContract
            ) {
                if (eligibleIndex >= _start && eligibleIndex < end) {
                    result[resultIndex] = auctions[i];
                    resultIndex++;
                }
                eligibleIndex++;
            }
        }

        return result;
    }

    /**
     * @dev Get total active listings count
     * @return Number of active listings
     */
    function getTotalActiveListings() external view returns (uint256) {
        uint256 count = 0;
        for (uint256 i = 0; i < listings.length; i++) {
            if (listings[i].isActive) {
                count++;
            }
        }
        return count;
    }

    /**
     * @dev Get total active auctions count
     * @return Number of active auctions
     */
    function getTotalActiveAuctions() external view returns (uint256) {
        uint256 count = 0;
        for (uint256 i = 0; i < auctions.length; i++) {
            if (auctions[i].status == 0) {
                count++;
            }
        }
        return count;
    }

    /**
     * @dev Get all auctions by price range
     * @param _priceRangeId Price range ID
     * @param _start Start index
     * @param _limit Max items to return
     * @return Array of auction data
     */
    function getAuctionsByPriceRange(
        uint256 _priceRangeId,
        uint256 _start,
        uint256 _limit
    ) external view returns (AuctionData[] memory) {
        uint256[] storage priceRangeAuctionIds = auctionsByPriceRange[
            _priceRangeId
        ];

        uint256 count = priceRangeAuctionIds.length;
        if (count == 0) {
            return new AuctionData[](0);
        }

        uint256 end = _start + _limit;
        if (end > count) {
            end = count;
        }
        if (_start >= end) {
            return new AuctionData[](0);
        }

        AuctionData[] memory result = new AuctionData[](end - _start);
        for (uint256 i = _start; i < end; i++) {
            result[i - _start] = auctions[priceRangeAuctionIds[i]];
        }

        return result;
    }

    /**
     * @dev Get all listings by price range
     * @param _priceRangeId Price range ID
     * @param _start Start index
     * @param _limit Max items to return
     * @return Array of listing data
     */
    function getListingsByPriceRange(
        uint256 _priceRangeId,
        uint256 _start,
        uint256 _limit
    ) external view returns (ListingData[] memory) {
        uint256[] storage priceRangeListingIds = listingsByPriceRange[
            _priceRangeId
        ];

        uint256 count = priceRangeListingIds.length;
        if (count == 0) {
            return new ListingData[](0);
        }

        uint256 end = _start + _limit;
        if (end > count) {
            end = count;
        }
        if (_start >= end) {
            return new ListingData[](0);
        }

        ListingData[] memory result = new ListingData[](end - _start);
        for (uint256 i = _start; i < end; i++) {
            result[i - _start] = listings[priceRangeListingIds[i]];
        }

        return result;
    }

    /**
     * @dev Helper function to update price range indexing when prices change
     * @param _itemId Item ID (listing or auction)
     * @param _oldPriceRange Old price range ID
     * @param _newPriceRange New price range ID
     * @param _isAuction True if auction, false if listing
     */
    function _updatePriceRangeIndex(
        uint256 _itemId,
        uint256 _oldPriceRange,
        uint256 _newPriceRange,
        bool _isAuction
    ) private {
        if (_isAuction) {
            _removeFromArray(auctionsByPriceRange[_oldPriceRange], _itemId);
            auctionsByPriceRange[_newPriceRange].push(_itemId);
        } else {
            _removeFromArray(listingsByPriceRange[_oldPriceRange], _itemId);
            listingsByPriceRange[_newPriceRange].push(_itemId);
        }
    }

    /**
     * @dev Helper function to remove an item from an array
     * @param _array Array to remove from
     * @param _item Item to remove
     */
    function _removeFromArray(uint256[] storage _array, uint256 _item) private {
        for (uint256 i = 0; i < _array.length; i++) {
            if (_array[i] == _item) {
                _array[i] = _array[_array.length - 1];
                _array.pop();
                break;
            }
        }
    }

    // Additional methods and helper functions would continue here...

    // Helper method to check if an array contains a value
    function _contains(
        uint256[] storage array,
        uint256 value
    ) private view returns (bool) {
        for (uint256 i = 0; i < array.length; i++) {
            if (array[i] == value) {
                return true;
            }
        }
        return false;
    }

    // Helper method to get price range ID
    function _getPriceRangeId(uint256 price) private pure returns (uint256) {
        if (price < 0.1 ether) {
            return 0;
        } else if (price < 0.5 ether) {
            return 1;
        } else if (price < 1 ether) {
            return 2;
        } else if (price < 5 ether) {
            return 3;
        } else if (price < 10 ether) {
            return 4;
        } else {
            return 5;
        }
    }

    // Update NFT auction status
    function _updateNFTAuctionStatus(
        address _nftContract,
        uint256 _tokenId,
        uint256 _auctionId,
        bool _isInAuction
    ) private {
        NFTData storage data = nftData[_nftContract][_tokenId];
        data.isInAuction = _isInAuction;
        if (_isInAuction) {
            data.auctionId = _auctionId;
        }
    }

    // Update NFT listing status
    function _updateNFTListingStatus(
        address _nftContract,
        uint256 _tokenId,
        uint256 _listingId,
        bool _isListed
    ) private {
        NFTData storage data = nftData[_nftContract][_tokenId];
        data.isListed = _isListed;
        if (_isListed) {
            data.listingId = _listingId;
        }
    }

    // Update NFT owner
    function _updateNFTOwner(
        address _nftContract,
        uint256 _tokenId,
        address _newOwner
    ) private {
        NFTData storage data = nftData[_nftContract][_tokenId];
        data.owner = _newOwner;
    }
}
