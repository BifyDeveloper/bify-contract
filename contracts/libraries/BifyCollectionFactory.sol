// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../NFTCollection.sol";

/**
 * @title BifyCollectionFactory
 * @dev Library for creating NFT collections in BifyLaunchpad
 */
library BifyCollectionFactory {
    /**
     * @notice Creates a new NFT collection
     * @param name Collection name
     * @param symbol Collection symbol
     * @param maxSupply Maximum supply of the collection
     * @param royaltyPercentage Royalty percentage (in basis points)
     * @param baseURI Base URI for collection metadata
     * @param mintStartTime Start time for public minting
     * @param mintEndTime End time for public minting
     * @param mintPrice Price per NFT during public mint
     * @param maxMintsPerWallet Maximum number of NFTs an address can mint
     * @param creator Owner of the collection
     * @return collection Address of the created collection
     */
    function createNFTCollection(
        string memory name,
        string memory symbol,
        uint256 maxSupply,
        uint96 royaltyPercentage,
        string memory baseURI,
        uint256 mintStartTime,
        uint256 mintEndTime,
        uint256 mintPrice,
        uint256 maxMintsPerWallet,
        address creator
    ) external returns (address collection) {
        NFTCollection newCollection = new NFTCollection(
            name,
            symbol,
            maxSupply,
            royaltyPercentage,
            baseURI,
            mintStartTime,
            mintEndTime,
            mintPrice,
            maxMintsPerWallet,
            creator,
            NFTCollection.RevealStrategy.STANDARD
        );

        return address(newCollection);
    }

    /**
     * @notice Creates a new NFT collection with whitelist support
     * @param name Collection name
     * @param symbol Collection symbol
     * @param maxSupply Maximum supply of the collection
     * @param royaltyPercentage Royalty percentage (in basis points)
     * @param baseURI Base URI for collection metadata
     * @param creator Owner of the collection
     * @param revealStrategy Reveal strategy for the collection
     * @return collection Address of the created collection
     */
    function createWhitelistCollection(
        string memory name,
        string memory symbol,
        uint256 maxSupply,
        uint96 royaltyPercentage,
        string memory baseURI,
        address creator,
        NFTCollection.RevealStrategy revealStrategy
    ) external returns (address collection) {
        NFTCollection newCollection = new NFTCollection(
            name,
            symbol,
            maxSupply,
            royaltyPercentage,
            baseURI,
            0, // mintStartTime - will be set later
            0, // mintEndTime - will be set later
            0, // mintPrice - will be set later
            0, // maxMintsPerWallet - will be set later
            creator,
            revealStrategy
        );

        return address(newCollection);
    }
}
