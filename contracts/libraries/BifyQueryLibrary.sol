// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../interfaces/IBifyLaunchpadStorage.sol";
import "../BifyLaunchpadLibrary.sol";
import "../IWhitelistManagerExtended.sol";
import "../NFTCollection.sol";

/**
 * @title BifyQueryLibrary
 * @dev Library for query functions to reduce size of BifyLaunchpadQuery contract
 * @notice Enhanced with additional functions to fully support the optimized BifyLaunchpadQuery
 */
library BifyQueryLibrary {
    error CollectionNotRegistered();
    error NotAuthorized();
    error StorageNotInitialized();

    /**
     * @dev Helper function to validate collection registration
     * @param storageContract Storage contract reference
     * @param _collection Collection address to validate
     * @return True if the collection is registered, reverts otherwise
     */
    function _validateCollection(
        address storageContract,
        address _collection
    ) internal view returns (bool) {
        IBifyLaunchpadStorage storageRef = IBifyLaunchpadStorage(
            storageContract
        );
        bool isRegistered = storageRef.registeredCollections(_collection);
        if (!isRegistered) revert CollectionNotRegistered();
        return isRegistered;
    }

    /**
     * @dev Helper function to retrieve collection data efficiently
     * @param storageContract Storage contract reference
     * @param _collection Collection address
     * @return collectionData The collection data in memory
     */
    function _getCollectionData(
        address storageContract,
        address _collection
    )
        internal
        view
        returns (BifyLaunchpadLibrary.CollectionData memory collectionData)
    {
        _validateCollection(storageContract, _collection);
        IBifyLaunchpadStorage storageRef = IBifyLaunchpadStorage(
            storageContract
        );

        (
            address creator,
            string memory name,
            string memory symbol,
            uint256 maxSupply,
            uint256 royaltyPercentage,
            uint256 createdAt,
            bool whitelistEnabled,
            address whitelistContract,
            BifyLaunchpadLibrary.LaunchPhase memory whitelistPhase,
            BifyLaunchpadLibrary.LaunchPhase memory publicPhase,
            bool deployed,
            uint256 totalMinted,
            uint256 uniqueHolders
        ) = storageRef.collectionsData(_collection);

        collectionData = BifyLaunchpadLibrary.CollectionData({
            creator: creator,
            name: name,
            symbol: symbol,
            maxSupply: maxSupply,
            royaltyPercentage: uint96(royaltyPercentage),
            createdAt: createdAt,
            whitelistEnabled: whitelistEnabled,
            whitelistContract: whitelistContract,
            whitelistPhase: whitelistPhase,
            publicPhase: publicPhase,
            deployed: deployed,
            totalMinted: totalMinted,
            uniqueHolders: uniqueHolders
        });
    }

    /**
     * @notice Get all collections created by a specific address
     * @param storageContract Storage contract reference
     * @param _creator Creator address
     * @return collections Array of collection addresses created by this address
     */
    function getCreatorCollections(
        address storageContract,
        address _creator
    ) external view returns (address[] memory) {
        IBifyLaunchpadStorage storageRef = IBifyLaunchpadStorage(
            storageContract
        );
        uint256 totalCount = storageRef.collectionCount();

        address[] memory tempResult = new address[](totalCount);
        uint256 resultCount = 0;

        for (uint256 i = 0; i < totalCount; i++) {
            address collectionAddress = storageRef.collectionByIndex(i);
            (address creator, , , , , , , , , , , , ) = storageRef
                .collectionsData(collectionAddress);
            if (creator == _creator) {
                tempResult[resultCount++] = collectionAddress;
            }
        }

        address[] memory result = new address[](resultCount);
        for (uint256 i = 0; i < resultCount; i++) {
            result[i] = tempResult[i];
        }

        return result;
    }

    /**
     * @notice Get all collections with pagination
     * @param storageContract Storage contract reference
     * @param _start Starting index
     * @param _limit Maximum number of items to return
     * @return collections Array of collection addresses
     */
    function getAllCollections(
        address storageContract,
        uint256 _start,
        uint256 _limit
    ) external view returns (address[] memory) {
        IBifyLaunchpadStorage storageRef = IBifyLaunchpadStorage(
            storageContract
        );
        uint256 totalCount = storageRef.collectionCount();

        uint256 end = _start + _limit;
        if (end > totalCount) {
            end = totalCount;
        }

        uint256 resultLength = end > _start ? end - _start : 0;
        address[] memory result = new address[](resultLength);

        for (uint256 i = _start; i < end; i++) {
            result[i - _start] = storageRef.collectionByIndex(i);
        }

        return result;
    }

    /**
     * @notice Get collections by category with pagination
     * @param storageContract Storage contract reference
     * @param _category Category to filter by
     * @param _start Starting index
     * @param _limit Maximum number of items to return
     * @return collections Array of collection addresses
     */
    function getCollectionsByCategory(
        address storageContract,
        bytes32 _category,
        uint256 _start,
        uint256 _limit
    ) external view returns (address[] memory) {
        IBifyLaunchpadStorage storageRef = IBifyLaunchpadStorage(
            storageContract
        );
        uint256 totalCategoryCount = storageRef.categoryCount(_category);

        uint256 end = _start + _limit;
        if (end > totalCategoryCount) {
            end = totalCategoryCount;
        }

        uint256 resultLength = end > _start ? end - _start : 0;
        address[] memory result = new address[](resultLength);

        for (uint256 i = _start; i < end; i++) {
            address collectionAddress = storageRef.collectionsByCategory(
                _category,
                i
            );
            result[i - _start] = collectionAddress;
        }

        return result;
    }

    /**
     * @notice Retrieves the currently active phase for a collection
     * @param storageContract Storage contract reference
     * @param _collection Collection address
     * @return whitelistActive Whether whitelist phase is active
     * @return publicActive Whether public phase is active
     * @return activePrice Current active price
     * @return timeRemaining Time remaining in current phase
     */
    function getActivePhase(
        address storageContract,
        address _collection
    )
        external
        view
        returns (
            bool whitelistActive,
            bool publicActive,
            uint256 activePrice,
            uint256 timeRemaining
        )
    {
        BifyLaunchpadLibrary.CollectionData memory data = _getCollectionData(
            storageContract,
            _collection
        );

        uint256 currentTime = block.timestamp;

        if (
            data.whitelistEnabled &&
            data.whitelistPhase.active &&
            currentTime >= data.whitelistPhase.startTime &&
            currentTime <= data.whitelistPhase.endTime
        ) {
            whitelistActive = true;
            activePrice = data.whitelistPhase.price;
            timeRemaining = data.whitelistPhase.endTime - currentTime;
            return (whitelistActive, publicActive, activePrice, timeRemaining);
        }

        if (
            data.publicPhase.active &&
            currentTime >= data.publicPhase.startTime &&
            currentTime <= data.publicPhase.endTime
        ) {
            publicActive = true;
            activePrice = data.publicPhase.price;
            timeRemaining = data.publicPhase.endTime - currentTime;
        }

        return (whitelistActive, publicActive, activePrice, timeRemaining);
    }

    /**
     * @notice Get collection information
     * @param storageContract Storage contract reference
     * @param _collection Collection address
     * @return creator Collection creator address
     * @return name Collection name
     * @return symbol Collection symbol
     * @return maxSupply Maximum supply of the collection
     * @return royaltyPercentage Royalty percentage
     * @return createdAt Creation timestamp
     * @return whitelistEnabled Whether whitelist is enabled
     * @return whitelistContract Whitelist contract address
     * @return totalMinted Total number of minted tokens
     * @return uniqueHolders Number of unique token holders
     */
    function getCollectionInfo(
        address storageContract,
        address _collection
    )
        external
        view
        returns (
            address creator,
            string memory name,
            string memory symbol,
            uint256 maxSupply,
            uint256 royaltyPercentage,
            uint256 createdAt,
            bool whitelistEnabled,
            address whitelistContract,
            uint256 totalMinted,
            uint256 uniqueHolders
        )
    {
        BifyLaunchpadLibrary.CollectionData memory data = _getCollectionData(
            storageContract,
            _collection
        );

        return (
            data.creator,
            data.name,
            data.symbol,
            data.maxSupply,
            data.royaltyPercentage,
            data.createdAt,
            data.whitelistEnabled,
            data.whitelistContract,
            data.totalMinted,
            data.uniqueHolders
        );
    }

    /**
     * @notice Get collection phases information
     * @param storageContract Storage contract reference
     * @param _collection Collection address
     * @return whitelistStart Whitelist phase start time
     * @return whitelistEnd Whitelist phase end time
     * @return whitelistPrice Whitelist phase price
     * @return whitelistMaxPerWallet Whitelist max per wallet
     * @return whitelistActive Whether whitelist phase is active
     * @return publicStart Public phase start time
     * @return publicEnd Public phase end time
     * @return publicPrice Public phase price
     * @return publicMaxPerWallet Public phase max per wallet
     * @return publicActive Whether public phase is active
     */
    function getCollectionPhases(
        address storageContract,
        address _collection
    )
        external
        view
        returns (
            uint256 whitelistStart,
            uint256 whitelistEnd,
            uint256 whitelistPrice,
            uint256 whitelistMaxPerWallet,
            bool whitelistActive,
            uint256 publicStart,
            uint256 publicEnd,
            uint256 publicPrice,
            uint256 publicMaxPerWallet,
            bool publicActive
        )
    {
        BifyLaunchpadLibrary.CollectionData memory data = _getCollectionData(
            storageContract,
            _collection
        );

        return (
            data.whitelistPhase.startTime,
            data.whitelistPhase.endTime,
            data.whitelistPhase.price,
            data.whitelistPhase.maxPerWallet,
            data.whitelistPhase.active,
            data.publicPhase.startTime,
            data.publicPhase.endTime,
            data.publicPhase.price,
            data.publicPhase.maxPerWallet,
            data.publicPhase.active
        );
    }

    /**
     * @notice Check if a user is whitelisted for a collection
     * @param storageContract Storage contract reference
     * @param _collection Collection address
     * @param _user User address
     * @return isWhitelisted Whether the user is whitelisted
     */
    function isWhitelistedUser(
        address storageContract,
        address _collection,
        address _user
    ) external view returns (bool) {
        BifyLaunchpadLibrary.CollectionData memory data = _getCollectionData(
            storageContract,
            _collection
        );

        if (!data.whitelistEnabled || data.whitelistContract == address(0)) {
            return false;
        }

        IWhitelistManagerExtended wlManager = IWhitelistManagerExtended(
            data.whitelistContract
        );

        bytes32[] memory proof = new bytes32[](0);

        uint256 tier = 1;
        return wlManager.isWhitelisted(_user, tier, proof);
    }

    /**
     * @notice Get platform fee
     * @param storageContract Storage contract reference
     * @return fee The platform fee
     */
    function getPlatformFee(
        address storageContract
    ) external view returns (uint256) {
        return IBifyLaunchpadStorage(storageContract).platformFee();
    }

    /**
     * @notice Get Bify fee
     * @param storageContract Storage contract reference
     * @return fee The Bify fee
     */
    function getBifyFee(
        address storageContract
    ) external view returns (uint256) {
        return IBifyLaunchpadStorage(storageContract).bifyFee();
    }

    /**
     * @notice Get fee recipient
     * @param storageContract Storage contract reference
     * @return recipient The fee recipient address
     */
    function getFeeRecipient(
        address storageContract
    ) external view returns (address) {
        return IBifyLaunchpadStorage(storageContract).feeRecipient();
    }

    /**
     * @notice Check if Bify payment is allowed
     * @param storageContract Storage contract reference
     * @return allowed Whether Bify payment is allowed
     */
    function isBifyPaymentAllowed(
        address storageContract
    ) external view returns (bool) {
        return IBifyLaunchpadStorage(storageContract).allowBifyPayment();
    }

    /**
     * @notice Get whitelist manager for a collection
     * @param storageContract Storage contract reference
     * @param _collection Collection address
     * @return manager The whitelist manager address
     */
    function getWhitelistManager(
        address storageContract,
        address _collection
    ) external view returns (address) {
        BifyLaunchpadLibrary.CollectionData memory data = _getCollectionData(
            storageContract,
            _collection
        );
        return data.whitelistContract;
    }

    /**
     * @notice Check if a collection is registered
     * @param storageContract Storage contract reference
     * @param _collection Collection address
     * @return registered Whether the collection is registered
     */
    function isCollectionRegistered(
        address storageContract,
        address _collection
    ) external view returns (bool) {
        IBifyLaunchpadStorage storageRef = IBifyLaunchpadStorage(
            storageContract
        );
        return storageRef.registeredCollections(_collection);
    }

    /**
     * @notice Get the Bify token address
     * @param storageContract Storage contract reference
     * @return tokenAddress The Bify token address
     */
    function getBifyToken(
        address storageContract
    ) external view returns (address) {
        return address(IBifyLaunchpadStorage(storageContract).bifyToken());
    }
}
