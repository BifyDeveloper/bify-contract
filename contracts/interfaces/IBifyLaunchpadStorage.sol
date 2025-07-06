// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../BifyLaunchpadLibrary.sol";

/**
 * @title IBifyLaunchpadStorage
 * @dev Interface for BifyLaunchpadStorage to be used in query libraries and contracts
 */
interface IBifyLaunchpadStorage {
    function platformFee() external view returns (uint256);
    function feeRecipient() external view returns (address);
    function bifyToken() external view returns (IERC20);
    function allowBifyPayment() external view returns (bool);
    function bifyFee() external view returns (uint256);
    function whitelistManagerFactory() external view returns (address);
    function authorizedOperators(address operator) external view returns (bool);

    function creatorCollections(
        address creator,
        uint256 index
    ) external view returns (address);
    function registeredCollections(
        address collection
    ) external view returns (bool);
    function allCollections(uint256 index) external view returns (address);

    function collectionsData(
        address collection
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
            BifyLaunchpadLibrary.LaunchPhase memory whitelistPhase,
            BifyLaunchpadLibrary.LaunchPhase memory publicPhase,
            bool deployed,
            uint256 totalMinted,
            uint256 uniqueHolders
        );

    function collectionByIndex(uint256 index) external view returns (address);
    function collectionCount() external view returns (uint256);

    function collectionsByCategory(
        bytes32 category,
        uint256 index
    ) external view returns (address);
    function categoryCount(bytes32 category) external view returns (uint256);

    function isCollectionCreator(
        address _collection,
        address _address
    ) external view returns (bool);
}
