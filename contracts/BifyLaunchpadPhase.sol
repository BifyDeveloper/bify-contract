// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./BifyLaunchpadPhaseCore.sol";
import "./IWhitelistManagerExtended.sol";

contract BifyLaunchpadPhase is BifyLaunchpadPhaseCore {
    constructor(
        address _storageContract,
        uint256 _platformFee,
        address _feeRecipient,
        address _bifyToken,
        uint256 _bifyFee
    )
        BifyLaunchpadPhaseCore(
            _storageContract,
            _platformFee,
            _feeRecipient,
            _bifyToken,
            _bifyFee
        )
    {}

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
}
