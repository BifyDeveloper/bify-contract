// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../BifyLaunchpadLibrary.sol";
import "../WhitelistManagerFactory.sol";
import "../NFTCollection.sol";

/**
 * @title BifyWhitelistManager
 * @dev Library for whitelist management in BifyLaunchpad
 */
library BifyWhitelistManager {
    /**
     * @notice Create a whitelist manager contract for a collection
     * @param whitelistManagerFactory The factory contract address
     * @param whitelistName Name for the whitelist
     * @return whitelistContract Address of the created whitelist manager contract
     */
    function createWhitelistContract(
        address whitelistManagerFactory,
        string memory whitelistName
    ) external returns (address whitelistContract) {
        require(whitelistManagerFactory != address(0), "Factory not set");
        WhitelistManagerFactory factory = WhitelistManagerFactory(
            whitelistManagerFactory
        );
        return factory.createWhitelistManager(whitelistName);
    }

    /**
     * @notice Configure whitelist settings in the NFT collection
     * @param collectionAddress Address of the NFT collection
     * @param whitelistContract Address of the whitelist manager contract
     * @param startTime Start time for whitelist phase
     * @param endTime End time for whitelist phase
     */
    function configureCollectionWhitelist(
        address collectionAddress,
        address whitelistContract,
        uint256 startTime,
        uint256 endTime
    ) external {
        NFTCollection collection = NFTCollection(payable(collectionAddress));
        collection.setExternalWhitelist(whitelistContract, startTime, endTime);
    }

    /**
     * @notice Validate a whitelist manager contract
     * @param whitelistContract Address of the whitelist manager contract
     * @return valid Whether the contract is valid
     */
    function validateWhitelistContract(
        address whitelistContract
    ) external view returns (bool valid) {
        if (whitelistContract == address(0)) return false;
        uint256 codeSize;
        assembly {
            codeSize := extcodesize(whitelistContract)
        }
        return codeSize > 0;
    }
}
