// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./BifyLaunchpadCore.sol";
import "./storage/BifyLaunchpadStorage.sol";
import "./NFTCollection.sol";
import "./BifyLaunchpadLibrary.sol";

/**
 * @title BifyLaunchpadPhase
 * @notice Manages collection phases (whitelist and public) for the launchpad. This contract is a component of the modular Bify Launchpad system, responsible for phase configuration and state management for NFT collections.
 * @dev Should only be interacted with via the BifyLaunchpad facade contract, which handles authorization and coordination between components.
 */
contract BifyLaunchpadPhase is BifyLaunchpadCore {
    event WhitelistConfigUpdated(
        address indexed collection,
        uint256 startTime,
        uint256 endTime,
        uint256 price,
        uint256 maxPerWallet,
        bool active
    );

    event PublicPhaseConfigUpdated(
        address indexed collection,
        uint256 startTime,
        uint256 endTime,
        uint256 price,
        uint256 maxPerWallet,
        bool active
    );

    event PhaseStateChanged(
        address indexed collection,
        bool isWhitelistPhase,
        bool active
    );

    error InvalidTimeRange();
    error StartTimeInFuture();
    error WhitelistPhaseOverlap();
    error PublicPhaseOverlap();
    error WhitelistNotEnabled();
    error WhitelistPhaseNotActive();
    error PublicPhaseNotActive();
    error EmptyBaseURI();
    error InvalidWhitelistAddress();

    modifier validTimeRange(uint256 _startTime, uint256 _endTime) {
        if (_startTime >= _endTime) revert InvalidTimeRange();
        if (_startTime <= block.timestamp) revert StartTimeInFuture();
        _;
    }

    /**
     * @dev Constructor - passes all parameters to BifyLaunchpadCore, including the storage address
     */
    constructor(
        address _storageContract,
        uint256 _platformFee,
        address _feeRecipient,
        address _bifyToken,
        uint256 _bifyFee
    )
        BifyLaunchpadCore(
            _storageContract,
            _platformFee,
            _feeRecipient,
            _bifyToken,
            _bifyFee
        )
    {}

    /**
     * @notice Initialize storage values - called after contract authorization
     * @dev Must be called after the contract has been authorized in storage
     */
    function initialize() public virtual override onlyOwner {
        super.initialize();
    }

    /**
     * @notice Get the active storage contract
     * @return The storage contract to use
     */
    function _getStorage()
        internal
        view
        override
        returns (BifyLaunchpadStorage)
    {
        return BifyLaunchpadStorage(storageContract);
    }

    /**
     * @notice Get the creator of a collection
     * @param _collection Collection address
     * @return creator Creator address
     */
    function getCollectionCreator(
        address _collection
    ) internal view returns (address) {
        return getCollectionData(_collection).creator;
    }

    /**
     * @notice Helper function to get collection data and reduce stack depth
     * @param _collection Collection address
     * @return A CollectionData struct
     */
    function getCollectionData(
        address _collection
    ) internal view returns (BifyLaunchpadLibrary.CollectionData memory) {
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
        ) = _getStorage().collectionsData(_collection);

        return
            BifyLaunchpadLibrary.CollectionData({
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
     * @dev Helper function to update collection data and emit appropriate events
     * @param _collection Collection address
     * @param data Updated collection data
     * @param emitEvents Whether to emit events for the changes
     * @param isWhitelistPhase Whether the update is for whitelist phase (true) or public phase (false)
     */
    function _updateCollectionData(
        address _collection,
        BifyLaunchpadLibrary.CollectionData memory data,
        bool emitEvents,
        bool isWhitelistPhase
    ) internal {
        _getStorage().setCollectionData(_collection, data);

        if (emitEvents) {
            if (isWhitelistPhase) {
                emit WhitelistConfigUpdated(
                    _collection,
                    data.whitelistPhase.startTime,
                    data.whitelistPhase.endTime,
                    data.whitelistPhase.price,
                    data.whitelistPhase.maxPerWallet,
                    data.whitelistPhase.active
                );
            } else {
                emit PublicPhaseConfigUpdated(
                    _collection,
                    data.publicPhase.startTime,
                    data.publicPhase.endTime,
                    data.publicPhase.price,
                    data.publicPhase.maxPerWallet,
                    data.publicPhase.active
                );
            }
        }
    }

    /**
     * @dev Helper function to configure NFT collection with whitelist
     * @param _collection Collection address
     * @param _whitelistContract Address of whitelist manager contract
     * @param _startTime Start time for whitelist
     * @param _endTime End time for whitelist
     */
    function _configureExternalWhitelist(
        address _collection,
        address _whitelistContract,
        uint256 _startTime,
        uint256 _endTime
    ) internal {
        NFTCollection collection = NFTCollection(payable(_collection));
        collection.setExternalWhitelist(
            _whitelistContract,
            _startTime,
            _endTime
        );
    }

    /**
     * @notice Links an existing whitelist manager contract to a collection
     * @param _collection Collection address
     * @param _whitelistContract Whitelist manager contract address
     * @param _startTime Whitelist start time
     * @param _endTime Whitelist end time
     * @param _price Default price for whitelist mint
     */
    function setAdvancedWhitelist(
        address _collection,
        address _whitelistContract,
        uint256 _startTime,
        uint256 _endTime,
        uint256 _price
    ) external onlyOwner validTimeRange(_startTime, _endTime) {
        if (_whitelistContract == address(0)) revert InvalidWhitelistAddress();

        BifyLaunchpadLibrary.CollectionData memory data = getCollectionData(
            _collection
        );

        data.whitelistEnabled = true;
        data.whitelistPhase.startTime = _startTime;
        data.whitelistPhase.endTime = _endTime;
        data.whitelistPhase.price = _price;
        data.whitelistPhase.active = true;
        data.whitelistContract = _whitelistContract;

        _getStorage().setCollectionData(_collection, data);

        _configureExternalWhitelist(
            _collection,
            _whitelistContract,
            _startTime,
            _endTime
        );

        emit WhitelistEnabled(
            _collection,
            _whitelistContract,
            _startTime,
            _endTime,
            _price
        );
    }

    /**
     * @notice Enables the advanced whitelist for a collection
     * @param _collection Collection address
     * @param _whitelistManager Address of the whitelist manager contract
     */
    function enableAdvancedWhitelist(
        address _collection,
        address _whitelistManager
    ) external onlyOwner {
        if (_whitelistManager == address(0)) revert InvalidWhitelistAddress();

        BifyLaunchpadLibrary.CollectionData memory data = getCollectionData(
            _collection
        );

        data.whitelistEnabled = true;
        data.whitelistContract = _whitelistManager;

        _getStorage().setCollectionData(_collection, data);

        _configureExternalWhitelist(
            _collection,
            _whitelistManager,
            data.whitelistPhase.startTime,
            data.whitelistPhase.endTime
        );

        emit WhitelistEnabled(
            _collection,
            _whitelistManager,
            data.whitelistPhase.startTime,
            data.whitelistPhase.endTime,
            data.whitelistPhase.price
        );
    }

    /**
     * @notice Configures an advanced whitelist for a collection
     * @param _collection Collection address
     * @param _whitelistManager Whitelist manager contract address
     */
    function configureAdvancedWhitelist(
        address _collection,
        address _whitelistManager
    ) external onlyOwner {
        if (_whitelistManager == address(0)) revert InvalidWhitelistAddress();

        BifyLaunchpadLibrary.CollectionData memory data = getCollectionData(
            _collection
        );

        data.whitelistEnabled = true;
        data.whitelistContract = _whitelistManager;

        _getStorage().setCollectionData(_collection, data);

        _configureExternalWhitelist(
            _collection,
            _whitelistManager,
            data.whitelistPhase.startTime,
            data.whitelistPhase.endTime
        );

        emit AdvancedWhitelistEnabled(_collection, _whitelistManager);
    }

    /**
     * @notice Configures whitelist phase for a collection
     * @param _collection Collection address
     * @param _startTime Whitelist start time
     * @param _endTime Whitelist end time
     * @param _price Price per NFT during whitelist
     * @param _maxPerWallet Maximum NFTs per wallet during whitelist
     */
    function setWhitelistPhase(
        address _collection,
        uint256 _startTime,
        uint256 _endTime,
        uint256 _price,
        uint256 _maxPerWallet
    ) external onlyOwner validTimeRange(_startTime, _endTime) {
        BifyLaunchpadLibrary.CollectionData memory data = getCollectionData(
            _collection
        );

        if (data.publicPhase.active) {
            if (_endTime > data.publicPhase.startTime)
                revert WhitelistPhaseOverlap();
        }

        data.whitelistPhase.startTime = _startTime;
        data.whitelistPhase.endTime = _endTime;
        data.whitelistPhase.price = _price;
        data.whitelistPhase.maxPerWallet = _maxPerWallet;
        data.whitelistPhase.active = true;
        data.whitelistEnabled = true;

        _updateCollectionData(_collection, data, true, true);
    }

    /**
     * @notice Configures public phase for a collection
     * @param _collection Collection address
     * @param _startTime Public sale start time
     * @param _endTime Public sale end time
     * @param _price Price per NFT during public sale
     * @param _maxPerWallet Maximum NFTs per wallet during public sale
     */
    function setPublicPhase(
        address _collection,
        uint256 _startTime,
        uint256 _endTime,
        uint256 _price,
        uint256 _maxPerWallet
    ) external onlyOwner validTimeRange(_startTime, _endTime) {
        BifyLaunchpadLibrary.CollectionData memory data = getCollectionData(
            _collection
        );

        if (data.whitelistEnabled && data.whitelistPhase.active) {
            if (_startTime < data.whitelistPhase.endTime)
                revert PublicPhaseOverlap();
        }

        data.publicPhase.startTime = _startTime;
        data.publicPhase.endTime = _endTime;
        data.publicPhase.price = _price;
        data.publicPhase.maxPerWallet = _maxPerWallet;
        data.publicPhase.active = true;

        _updateCollectionData(_collection, data, true, false);
    }

    /**
     * @notice Toggles active state of a phase (whitelist or public)
     * @param _collection Collection address
     * @param _active Whether to activate or deactivate
     * @param _isWhitelistPhase Whether to toggle whitelist (true) or public (false) phase
     */
    function togglePhase(
        address _collection,
        bool _active,
        bool _isWhitelistPhase
    ) internal {
        BifyLaunchpadLibrary.CollectionData memory data = getCollectionData(
            _collection
        );

        if (_isWhitelistPhase) {
            data.whitelistPhase.active = _active;
        } else {
            data.publicPhase.active = _active;
        }

        _getStorage().setCollectionData(_collection, data);

        emit PhaseStateChanged(_collection, _isWhitelistPhase, _active);
    }

    /**
     * @notice Toggles active state of whitelist phase
     * @param _collection Collection address
     * @param _active Whether to activate or deactivate
     */
    function toggleWhitelistPhase(
        address _collection,
        bool _active
    ) external onlyOwner {
        togglePhase(_collection, _active, true);
    }

    /**
     * @notice Toggles active state of public phase
     * @param _collection Collection address
     * @param _active Whether to activate or deactivate
     */
    function togglePublicPhase(
        address _collection,
        bool _active
    ) external onlyOwner {
        togglePhase(_collection, _active, false);
    }

    /**
     * @notice Updates the public phase configuration
     * @param _collection Collection address
     * @param _startTime Public sale start time
     * @param _endTime Public sale end time
     * @param _price Price per NFT during public sale
     * @param _maxPerWallet Maximum NFTs per wallet during public sale
     */
    function updatePublicPhase(
        address _collection,
        uint256 _startTime,
        uint256 _endTime,
        uint256 _price,
        uint256 _maxPerWallet
    ) external onlyOwner validTimeRange(_startTime, _endTime) {
        BifyLaunchpadLibrary.CollectionData memory data = getCollectionData(
            _collection
        );

        if (!data.publicPhase.active) revert PublicPhaseNotActive();

        if (data.whitelistEnabled && data.whitelistPhase.active) {
            if (_startTime < data.whitelistPhase.endTime)
                revert PublicPhaseOverlap();
        }

        data.publicPhase.startTime = _startTime;
        data.publicPhase.endTime = _endTime;
        data.publicPhase.price = _price;
        data.publicPhase.maxPerWallet = _maxPerWallet;

        _updateCollectionData(_collection, data, true, false);
    }

    /**
     * @notice Updates the whitelist phase configuration
     * @param _collection Collection address
     * @param _startTime Whitelist start time
     * @param _endTime Whitelist end time
     * @param _price Price per NFT during whitelist
     * @param _maxPerWallet Maximum NFTs per wallet during whitelist
     */
    function updateWhitelistPhase(
        address _collection,
        uint256 _startTime,
        uint256 _endTime,
        uint256 _price,
        uint256 _maxPerWallet
    ) external onlyOwner validTimeRange(_startTime, _endTime) {
        BifyLaunchpadLibrary.CollectionData memory data = getCollectionData(
            _collection
        );

        if (!data.whitelistEnabled) revert WhitelistNotEnabled();
        if (!data.whitelistPhase.active) revert WhitelistPhaseNotActive();

        if (data.publicPhase.active) {
            if (_endTime > data.publicPhase.startTime)
                revert WhitelistPhaseOverlap();
        }

        data.whitelistPhase.startTime = _startTime;
        data.whitelistPhase.endTime = _endTime;
        data.whitelistPhase.price = _price;
        data.whitelistPhase.maxPerWallet = _maxPerWallet;

        _updateCollectionData(_collection, data, true, true);
    }

    /**
     * @notice Disables the whitelist phase for a collection
     * @param _collection Collection address
     */
    function disableWhitelistPhase(address _collection) external onlyOwner {
        togglePhase(_collection, false, true);
    }

    /**
     * @notice Disables the public phase for a collection
     * @param _collection Collection address
     */
    function disablePublicPhase(address _collection) external onlyOwner {
        togglePhase(_collection, false, false);
    }

    /**
     * @notice Updates the collection base URI
     * @param _collection Collection address
     * @param _newBaseURI New base URI for the collection
     */
    function updateCollectionBaseURI(
        address _collection,
        string memory _newBaseURI
    ) external onlyOwner {
        if (bytes(_newBaseURI).length == 0) revert EmptyBaseURI();

        NFTCollection collection = NFTCollection(payable(_collection));
        collection.setBaseURI(_newBaseURI);
    }
}
