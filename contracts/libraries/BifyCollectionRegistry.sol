// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../BifyLaunchpadLibrary.sol";

/**
 * @title BifyCollectionRegistry
 * @dev Library for BifyLaunchpad to handle collection registry operations
 */
library BifyCollectionRegistry {
    /**
     * @notice Registers a new collection in the registry data
     * @param creatorCollections Mapping of creator to collection addresses
     * @param registeredCollections Mapping of collection addresses to registration status
     * @param allCollections Array of all collection addresses
     * @param collectionCount Counter for total collections
     * @param collectionByIndex Mapping of index to collection address
     * @param collectionsByCategory Mapping of category to collection addresses
     * @param categoryCount Mapping of category to collection count
     * @param collectionsData Mapping of collection address to collection data
     * @param creator Address of the collection creator
     * @param collectionAddress Address of the collection
     * @param data Collection data struct
     * @param category Collection category
     * @return The incremented collection count
     */
    function registerCollection(
        mapping(address => address[]) storage creatorCollections,
        mapping(address => bool) storage registeredCollections,
        address[] storage allCollections,
        uint256 collectionCount,
        mapping(uint256 => address) storage collectionByIndex,
        mapping(bytes32 => address[]) storage collectionsByCategory,
        mapping(bytes32 => uint256) storage categoryCount,
        mapping(address => BifyLaunchpadLibrary.CollectionData)
            storage collectionsData,
        address creator,
        address collectionAddress,
        BifyLaunchpadLibrary.CollectionData memory data,
        bytes32 category,
        bytes32 emptyCategory
    ) external returns (uint256) {
        registeredCollections[collectionAddress] = true;
        creatorCollections[creator].push(collectionAddress);
        allCollections.push(collectionAddress);
        collectionByIndex[collectionCount] = collectionAddress;

        collectionsData[collectionAddress] = data;

        if (category != emptyCategory) {
            collectionsByCategory[category].push(collectionAddress);
            categoryCount[category]++;
        }

        return collectionCount + 1;
    }

    /**
     * @notice Updates mint tracking information for a collection
     * @param collectionsData Mapping of collection address to collection data
     * @param collection Collection address
     * @param quantity Number of NFTs minted
     * @param currentBalance Current NFT balance of the minter
     * @return totalMinted Updated total minted count
     */
    function updateMintTracking(
        mapping(address => BifyLaunchpadLibrary.CollectionData)
            storage collectionsData,
        address collection,
        address,
        uint256 quantity,
        uint256 currentBalance
    ) external returns (uint256) {
        uint256 newTotalMinted = collectionsData[collection].totalMinted +
            quantity;
        collectionsData[collection].totalMinted = newTotalMinted;

        if (currentBalance == 0 && quantity > 0) {
            collectionsData[collection].uniqueHolders++;
        }

        return newTotalMinted;
    }
}
