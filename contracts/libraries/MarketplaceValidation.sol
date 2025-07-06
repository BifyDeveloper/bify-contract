// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

/**
 * @title MarketplaceValidation
 * @dev Library to handle validation logic for BifyMarketplace, extracting common functions to reduce contract size
 */
library MarketplaceValidation {
    enum AuctionStatus {
        Active,
        Ended,
        Canceled
    }

    enum AssetType {
        NFT,
        RWA
    }

    /**
     * @notice Validate auction creation parameters
     * @param _nftContract Address of the NFT contract
     * @param _reservePrice Reserve price for the auction
     * @param _buyNowPrice Buy now price (0 to disable)
     * @param _startTime Auction start time
     * @param _endTime Auction end time
     * @param _royaltyPercentage Royalty percentage (in basis points)
     * @param _minRoyaltyPercentage Minimum allowed royalty percentage
     * @param _maxRoyaltyPercentage Maximum allowed royalty percentage
     */
    function validateAuctionParams(
        address _nftContract,
        uint256,
        uint256 _reservePrice,
        uint256 _buyNowPrice,
        uint256 _startTime,
        uint256 _endTime,
        uint256 _royaltyPercentage,
        uint256 _minRoyaltyPercentage,
        uint256 _maxRoyaltyPercentage
    ) public view {
        require(_nftContract != address(0), "Invalid NFT contract");
        require(_reservePrice > 0, "Reserve price must be > 0");
        require(_startTime > block.timestamp, "Start time must be in future");
        require(_endTime > _startTime, "End time must be after start time");
        require(_endTime - _startTime >= 1 hours, "Auction too short");
        require(_endTime - _startTime <= 30 days, "Auction too long");

        if (_buyNowPrice > 0) {
            require(
                _buyNowPrice > _reservePrice,
                "Buy now price must be > reserve"
            );
        }

        require(
            _royaltyPercentage >= _minRoyaltyPercentage &&
                _royaltyPercentage <= _maxRoyaltyPercentage,
            "Invalid royalty percentage"
        );
    }

    /**
     * @notice Validate listing creation parameters
     * @param _nftContract Address of the NFT contract
     * @param _price Listing price
     * @param _royaltyPercentage Royalty percentage (in basis points)
     * @param _minRoyaltyPercentage Minimum allowed royalty percentage
     * @param _maxRoyaltyPercentage Maximum allowed royalty percentage
     */
    function validateListingParams(
        address _nftContract,
        uint256,
        uint256 _price,
        uint256 _royaltyPercentage,
        uint256 _minRoyaltyPercentage,
        uint256 _maxRoyaltyPercentage
    ) public pure {
        require(_nftContract != address(0), "Invalid NFT contract");
        require(_price > 0, "Price must be > 0");

        require(
            _royaltyPercentage >= _minRoyaltyPercentage &&
                _royaltyPercentage <= _maxRoyaltyPercentage,
            "Invalid royalty percentage"
        );
    }

    /**
     * @notice Check NFT ownership and approval
     * @param _nftContract Address of the NFT contract
     * @param _tokenId Token ID of the NFT
     * @param _seller Seller address
     * @param _marketplaceAddress Address of the marketplace contract
     */
    function validateOwnershipAndApproval(
        address _nftContract,
        uint256 _tokenId,
        address _seller,
        address _marketplaceAddress
    ) public view {
        IERC721 nft = IERC721(_nftContract);
        require(nft.ownerOf(_tokenId) == _seller, "Not token owner");
        require(
            nft.isApprovedForAll(_seller, _marketplaceAddress) ||
                nft.getApproved(_tokenId) == _marketplaceAddress,
            "Not approved for marketplace"
        );
    }

    /**
     * @notice Calculate platform fee
     * @param _amount Amount to calculate fee from
     * @param _feePercentage Fee percentage in basis points
     * @param _basisPoints Basis points denominator (usually 1000)
     * @return fee The calculated fee amount
     */
    function calculatePlatformFee(
        uint256 _amount,
        uint256 _feePercentage,
        uint256 _basisPoints
    ) public pure returns (uint256 fee) {
        return (_amount * _feePercentage) / _basisPoints;
    }

    /**
     * @notice Calculate royalty amount
     * @param _amount Amount to calculate royalty from
     * @param _royaltyPercentage Royalty percentage in basis points
     * @param _basisPoints Basis points denominator (usually 1000)
     * @return royalty The calculated royalty amount
     */
    function calculateRoyalty(
        uint256 _amount,
        uint256 _royaltyPercentage,
        uint256 _basisPoints
    ) public pure returns (uint256 royalty) {
        return (_amount * _royaltyPercentage) / _basisPoints;
    }
}
