// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IBifyLaunchpadPhase
 * @dev Interface for BifyLaunchpadPhase
 */
interface IBifyLaunchpadPhase {
    function setWhitelistPhase(
        address _collection,
        uint256 _startTime,
        uint256 _endTime,
        uint256 _price,
        uint256 _maxPerWallet
    ) external;

    function setPublicPhase(
        address _collection,
        uint256 _startTime,
        uint256 _endTime,
        uint256 _price,
        uint256 _maxPerWallet
    ) external;

    function updatePublicPhase(
        address _collection,
        uint256 _startTime,
        uint256 _endTime,
        uint256 _price,
        uint256 _maxPerWallet
    ) external;

    function updateWhitelistPhase(
        address _collection,
        uint256 _startTime,
        uint256 _endTime,
        uint256 _price,
        uint256 _maxPerWallet
    ) external;

    function disableWhitelistPhase(address _collection) external;

    function disablePublicPhase(address _collection) external;

    function configureAdvancedWhitelist(
        address _collection,
        address _whitelistManager
    ) external;

    function updateCollectionBaseURI(
        address _collection,
        string memory _newBaseURI
    ) external;

    /**
     * @notice Toggles active state of whitelist phase
     */
    function toggleWhitelistPhase(address _collection, bool _active) external;

    /**
     * @notice Toggles active state of public phase
     */
    function togglePublicPhase(address _collection, bool _active) external;
}
