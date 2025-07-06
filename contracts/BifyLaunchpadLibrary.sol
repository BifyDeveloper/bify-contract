// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./NFTCollection.sol";

/**
 * @title BifyLaunchpadLibrary
 * @notice Shared data structures and utility functions for the Bify Launchpad system. Used by core, phase, and query contracts for consistent data handling.
 * @dev This library is part of a modular system and is not intended to be used directly by end users.
 */
library BifyLaunchpadLibrary {
    struct LaunchPhase {
        uint256 startTime;
        uint256 endTime;
        uint256 price;
        uint256 maxPerWallet;
        bool active;
    }

    struct CollectionData {
        address creator;
        string name;
        string symbol;
        uint256 maxSupply;
        uint96 royaltyPercentage;
        uint256 createdAt;
        bool whitelistEnabled;
        address whitelistContract;
        LaunchPhase whitelistPhase;
        LaunchPhase publicPhase;
        bool deployed;
        uint256 totalMinted;
        uint256 uniqueHolders;
    }

    /**
     * @notice Check if an address is the owner of a collection
     * @param _collection Collection address
     * @param _address Address to check
     * @return isOwner Whether the address is the owner
     */
    function isCollectionOwner(
        address _collection,
        address _address
    ) internal view returns (bool) {
        return NFTCollection(payable(_collection)).owner() == _address;
    }

    /**
     * @notice Validate collection parameters
     * @param _name Collection name
     * @param _symbol Collection symbol
     * @param _maxSupply Maximum supply
     * @param _royaltyPercentage Royalty percentage (in basis points)
     * @param _mintStartTime Start time for public minting
     * @param _mintEndTime End time for public minting
     */
    function validateCollectionParams(
        string memory _name,
        string memory _symbol,
        uint256 _maxSupply,
        uint96 _royaltyPercentage,
        uint256 _mintStartTime,
        uint256 _mintEndTime
    ) internal view {
        require(_mintStartTime < _mintEndTime, "Invalid time window");
        require(
            _mintStartTime > block.timestamp,
            "Start time must be in future"
        );
        require(_maxSupply > 0, "Supply must be > 0");
        require(_royaltyPercentage <= 1000, "Royalty cannot exceed 10%");
        require(bytes(_name).length > 0, "Name cannot be empty");
        require(bytes(_symbol).length > 0, "Symbol cannot be empty");
    }

    /**
     * @notice Create a new collection data struct
     */
    function createCollectionData(
        address _creator,
        string memory _name,
        string memory _symbol,
        uint256 _maxSupply,
        uint96 _royaltyPercentage,
        uint256 _mintStartTime,
        uint256 _mintEndTime,
        uint256 _mintPrice,
        uint256 _maxMintsPerWallet
    ) internal view returns (CollectionData memory) {
        return
            CollectionData({
                creator: _creator,
                name: _name,
                symbol: _symbol,
                maxSupply: _maxSupply,
                royaltyPercentage: _royaltyPercentage,
                createdAt: block.timestamp,
                whitelistEnabled: false,
                whitelistContract: address(0),
                whitelistPhase: LaunchPhase({
                    startTime: 0,
                    endTime: 0,
                    price: 0,
                    maxPerWallet: 0,
                    active: false
                }),
                publicPhase: LaunchPhase({
                    startTime: _mintStartTime,
                    endTime: _mintEndTime,
                    price: _mintPrice,
                    maxPerWallet: _maxMintsPerWallet,
                    active: true
                }),
                deployed: true,
                totalMinted: 0,
                uniqueHolders: 0
            });
    }
}
