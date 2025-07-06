// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IWhitelistManagerExtended
 * @dev Interface for the WhitelistManagerExtended contract
 */
interface IWhitelistManagerExtended {
    /**
     * @notice Whitelist tier levels
     */
    enum TierLevel {
        Invalid,
        Tier1,
        Tier2,
        Tier3
    }

    /**
     * @notice Create a new whitelist tier
     * @param _merkleRoot Merkle root of addresses in this tier
     * @param _startTime Start time for this tier
     * @param _endTime End time for this tier
     * @param _maxMintsPerWallet Maximum mints per wallet for this tier
     * @param _price Price for minting in this tier
     * @return tierId ID of the created tier
     */
    function createTier(
        bytes32 _merkleRoot,
        uint256 _startTime,
        uint256 _endTime,
        uint256 _maxMintsPerWallet,
        uint256 _price
    ) external returns (uint256 tierId);

    /**
     * @notice Update an existing tier
     * @param _tierId ID of the tier to update
     * @param _merkleRoot New merkle root
     * @param _startTime New start time
     * @param _endTime New end time
     * @param _maxMintsPerWallet New max mints per wallet
     * @param _price New price
     * @param _active Whether the tier is active
     */
    function updateTier(
        uint256 _tierId,
        bytes32 _merkleRoot,
        uint256 _startTime,
        uint256 _endTime,
        uint256 _maxMintsPerWallet,
        uint256 _price,
        bool _active
    ) external;

    /**
     * @notice Add an address to the direct whitelist
     * @param _user Address to add
     * @param _tier Tier level
     */
    function addToDirectWhitelist(address _user, TierLevel _tier) external;

    /**
     * @notice Batch add addresses to the direct whitelist
     * @param _users Array of addresses to add
     * @param _tier Tier level for all addresses
     * @return successCount Number of successfully added addresses
     */
    function batchAddToDirectWhitelist(
        address[] calldata _users,
        TierLevel _tier
    ) external returns (uint256 successCount);

    /**
     * @notice Check if a user is whitelisted for a specific tier
     * @param _user User address to check
     * @param _tierId Tier ID to check
     * @param _merkleProof Merkle proof for verification
     * @return Whether the user is whitelisted for this tier
     */
    function isWhitelisted(
        address _user,
        uint256 _tierId,
        bytes32[] calldata _merkleProof
    ) external view returns (bool);

    /**
     * @notice Get the price for a specific tier
     * @param _tierId Tier ID to check
     * @return Price for the tier
     */
    function getTierPrice(uint256 _tierId) external view returns (uint256);

    /**
     * @notice Get the number of available mints for a user in a tier
     * @param _user User address to check
     * @param _tierId Tier ID to check
     * @return Number of available mints
     */
    function getAvailableMints(
        address _user,
        uint256 _tierId
    ) external view returns (uint256);

    /**
     * @notice Track a mint for a user in a tier
     * @param _user User address
     * @param _tierId Tier ID
     * @param _quantity Number of NFTs minted
     */
    function trackMint(
        address _user,
        uint256 _tierId,
        uint256 _quantity
    ) external;

    /**
     * @notice Check if a tier is currently active
     * @param _tierId Tier ID to check
     * @return Whether the tier is active and within time window
     */
    function checkTierActive(uint256 _tierId) external view returns (bool);

    /**
     * @notice Get all tier info at once
     * @param _tierId Tier ID to query
     * @return merkleRoot Merkle root for the tier
     * @return startTime Start time for the tier
     * @return endTime End time for the tier
     * @return maxMintsPerWallet Maximum mints per wallet for the tier
     * @return price Price for minting in this tier
     * @return active Whether the tier is active
     */
    function getTierInfoDetailed(
        uint256 _tierId
    )
        external
        view
        returns (
            bytes32 merkleRoot,
            uint256 startTime,
            uint256 endTime,
            uint256 maxMintsPerWallet,
            uint256 price,
            bool active
        );

    /**
     * @notice Get the total number of tiers
     */
    function tierCount() external view returns (uint256);

    /**
     * @notice Get the direct whitelist tier for a user
     * @param user The address to check
     * @return tierLevel The tier level (uint8)
     */
    function getDirectWhitelistTier(address user) external view returns (uint8);
}
