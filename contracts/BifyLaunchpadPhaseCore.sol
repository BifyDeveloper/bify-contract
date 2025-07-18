// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./BifyLaunchpadCore.sol";
import "./storage/BifyLaunchpadStorage.sol";
import "./NFTCollection.sol";
import "./BifyLaunchpadLibrary.sol";

contract BifyLaunchpadPhaseCore is BifyLaunchpadCore {
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

    modifier validTimeRange(uint256 _startTime, uint256 _endTime) {
        if (_startTime >= _endTime) revert InvalidTimeRange();
        if (_startTime <= block.timestamp) revert StartTimeInFuture();
        _;
    }

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

    function initialize() public virtual override onlyOwner {
        super.initialize();
    }

    function _getStorage()
        internal
        view
        override
        returns (BifyLaunchpadStorage)
    {
        return BifyLaunchpadStorage(storageContract);
    }

    function getCollectionCreator(
        address _collection
    ) internal view returns (address) {
        return getCollectionData(_collection).creator;
    }

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

    function toggleWhitelistPhase(
        address _collection,
        bool _active
    ) external onlyOwner {
        togglePhase(_collection, _active, true);
    }

    function togglePublicPhase(
        address _collection,
        bool _active
    ) external onlyOwner {
        togglePhase(_collection, _active, false);
    }

    function disableWhitelistPhase(address _collection) external onlyOwner {
        togglePhase(_collection, false, true);
    }

    function disablePublicPhase(address _collection) external onlyOwner {
        togglePhase(_collection, false, false);
    }

    function updateCollectionBaseURI(
        address _collection,
        string memory _newBaseURI
    ) external onlyOwner {
        if (bytes(_newBaseURI).length == 0) revert EmptyBaseURI();

        NFTCollection collection = NFTCollection(payable(_collection));
        collection.setBaseURI(_newBaseURI);
    }
}
