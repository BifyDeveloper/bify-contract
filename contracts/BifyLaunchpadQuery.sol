// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./BifyLaunchpadQueryBase.sol";
import "./libraries/BifyQueryLibrary.sol";
import "./interfaces/IBifyLaunchpadStorage.sol";
import "./storage/BifyLaunchpadStorage.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title BifyLaunchpadQuery
 * @notice Provides read-only query functions for the Bify Launchpad system
 * @dev Optimized inheritance model to reduce contract size
 */
contract BifyLaunchpadQuery is BifyLaunchpadQueryBase {
    /**
     * @dev Constructor - passes all parameters to BifyLaunchpadQueryBase
     */
    constructor(
        address _storageContract,
        uint256 _platformFee,
        address _feeRecipient,
        address _bifyToken,
        uint256 _bifyFee
    )
        BifyLaunchpadQueryBase(
            _storageContract,
            _platformFee,
            _feeRecipient,
            _bifyToken,
            _bifyFee
        )
    {}

    /**
     * @notice Override the initialize function from parent to initialize this contract
     */
    function initialize() public override onlyOwner {
        super.initialize();

        BifyLaunchpadStorage storageRef = BifyLaunchpadStorage(storageContract);

        storageRef.setPlatformFee(_platformFee);
        storageRef.setFeeRecipient(_feeRecipient);

        if (_bifyToken != address(0)) {
            storageRef.setBifyToken(_bifyToken);
            storageRef.setBifyFee(_bifyFee);
            storageRef.setAllowBifyPayment(true);
        }
    }

    /**
     * @notice Get all collections created by a specific address
     * @param _creator Creator address
     * @return collections Array of collection addresses created by this address
     */
    function getCreatorCollections(
        address _creator
    ) external view returns (address[] memory) {
        return
            BifyQueryLibrary.getCreatorCollections(storageContract, _creator);
    }

    /**
     * @notice Get all collections with pagination
     * @param _start Starting index
     * @param _limit Maximum number of items to return
     * @return collections Array of collection addresses
     */
    function getAllCollections(
        uint256 _start,
        uint256 _limit
    ) external view returns (address[] memory) {
        return
            BifyQueryLibrary.getAllCollections(storageContract, _start, _limit);
    }

    /**
     * @notice Get collections by category with pagination
     * @param _category Category to filter by
     * @param _start Starting index
     * @param _limit Maximum number of items to return
     * @return collections Array of collection addresses
     */
    function getCollectionsByCategory(
        bytes32 _category,
        uint256 _start,
        uint256 _limit
    ) external view returns (address[] memory) {
        return
            BifyQueryLibrary.getCollectionsByCategory(
                storageContract,
                _category,
                _start,
                _limit
            );
    }

    /**
     * @notice Retrieves the currently active phase for a collection
     * @param _collection Collection address
     * @return whitelistActive Whether whitelist phase is active
     * @return publicActive Whether public phase is active
     * @return activePrice Current active price
     * @return timeRemaining Time remaining in current phase
     */
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
        )
    {
        return BifyQueryLibrary.getActivePhase(storageContract, _collection);
    }

    /**
     * @notice Get collection information
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
        return BifyQueryLibrary.getCollectionInfo(storageContract, _collection);
    }

    /**
     * @notice Get collection phases information
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
        return
            BifyQueryLibrary.getCollectionPhases(storageContract, _collection);
    }

    /**
     * @notice Check if a user is whitelisted for a collection
     * @param _collection Collection address
     * @param _user User address
     * @return isWhitelisted Whether the user is whitelisted
     */
    function isWhitelistedUser(
        address _collection,
        address _user
    ) external view returns (bool) {
        return
            BifyQueryLibrary.isWhitelistedUser(
                storageContract,
                _collection,
                _user
            );
    }

    /**
     * @notice Get platform fee
     * @return fee The platform fee
     */
    function getPlatformFee() external view returns (uint256) {
        return BifyQueryLibrary.getPlatformFee(storageContract);
    }

    /**
     * @notice Get Bify fee
     * @return fee The Bify fee
     */
    function getBifyFee() external view returns (uint256) {
        return BifyQueryLibrary.getBifyFee(storageContract);
    }

    /**
     * @notice Get fee recipient
     * @return recipient The fee recipient address
     */
    function getFeeRecipient() external view returns (address) {
        return BifyQueryLibrary.getFeeRecipient(storageContract);
    }

    /**
     * @notice Check if Bify payment is allowed
     * @return allowed Whether Bify payment is allowed
     */
    function isBifyPaymentAllowed() external view returns (bool) {
        return BifyQueryLibrary.isBifyPaymentAllowed(storageContract);
    }

    /**
     * @notice Get whitelist manager for a collection
     * @param _collection Collection address
     * @return manager The whitelist manager address
     */
    function getWhitelistManager(
        address _collection
    ) external view returns (address) {
        return
            BifyQueryLibrary.getWhitelistManager(storageContract, _collection);
    }

    /**
     * @notice Check if a collection is registered
     * @param _collection Collection address
     * @return registered Whether the collection is registered
     */
    function isCollectionRegistered(
        address _collection
    ) external view returns (bool) {
        return
            BifyQueryLibrary.isCollectionRegistered(
                storageContract,
                _collection
            );
    }
}
