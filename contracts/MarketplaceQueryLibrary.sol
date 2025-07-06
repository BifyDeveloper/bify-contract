// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title MarketplaceQueryLibrary
 * @dev Helper library for MarketplaceQuery to reduce contract size
 */
library MarketplaceQueryLibrary {
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

    /**
     * @dev Creates a new auction data struct
     */
    function createAuctionData(
        uint256 _auctionId,
        address _seller,
        address _nftContract,
        uint256 _tokenId,
        uint256 _reservePrice,
        uint256 _buyNowPrice,
        uint256 _startTime,
        uint256 _endTime,
        uint256 _royaltyPercentage,
        uint8 _assetType
    ) internal view returns (AuctionData memory) {
        return
            AuctionData({
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
    }

    /**
     * @dev Creates a new listing data struct
     */
    function createListingData(
        uint256 _listingId,
        address _seller,
        address _nftContract,
        uint256 _tokenId,
        uint256 _price,
        uint8 _assetType,
        uint256 _royaltyPercentage
    ) internal view returns (ListingData memory) {
        return
            ListingData({
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
    }
}
