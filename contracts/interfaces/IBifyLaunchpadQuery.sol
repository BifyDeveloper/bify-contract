// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../BifyLaunchpadLibrary.sol";

/**
 * @title IBifyLaunchpadQuery
 * @dev Interface for BifyLaunchpadQuery
 */
interface IBifyLaunchpadQuery {
    function getCreatorCollections(
        address _creator
    ) external view returns (address[] memory);

    function getAllCollections(
        uint256 _start,
        uint256 _limit
    ) external view returns (address[] memory);

    function getCollectionsByCategory(
        bytes32 _category,
        uint256 _start,
        uint256 _limit
    ) external view returns (address[] memory);

    function getActivePhase(
        address _collection
    )
        external
        view
        returns (
            bool whitelistActive,
            bool publicActive,
            uint256 activePrice,
            uint256 timeRemaining
        );

    function getCollectionInfo(
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
        );

    function getCollectionPhases(
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
        );

    function isWhitelistedUser(
        address _collection,
        address _user
    ) external view returns (bool);

    function getPlatformFee() external view returns (uint256);

    function getBifyFee() external view returns (uint256);

    function getFeeRecipient() external view returns (address);

    function isBifyPaymentAllowed() external view returns (bool);

    function getWhitelistManager(
        address _collection
    ) external view returns (address);

    function isCollectionRegistered(
        address _collection
    ) external view returns (bool);

    function getTotalCollections() external view returns (uint256);

    function getCategoryCount(
        bytes32 _category
    ) external view returns (uint256);
}
