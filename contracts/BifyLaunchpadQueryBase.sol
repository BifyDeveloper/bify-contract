// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title BifyLaunchpadQueryBase
 * @notice Base contract for BifyLaunchpadQuery with minimal inheritance
 * @dev This optimized base class reduces contract size by minimizing inheritance
 */
contract BifyLaunchpadQueryBase is Ownable {
    address public immutable storageContract;
    bool private _initialized = false;

    uint256 internal _platformFee;
    address internal _feeRecipient;
    address internal _bifyToken;
    uint256 internal _bifyFee;

    /**
     * @dev Constructor - stores references but doesn't modify storage
     * @param _storageContract Address of the BifyLaunchpadStorage contract
     * @param _initialPlatformFee Initial platform fee
     * @param _initialFeeRecipient Initial fee recipient address
     * @param _initialBifyToken Address of Bify token
     * @param _initialBifyFee Initial Bify fee
     */
    constructor(
        address _storageContract,
        uint256 _initialPlatformFee,
        address _initialFeeRecipient,
        address _initialBifyToken,
        uint256 _initialBifyFee
    ) {
        require(_storageContract != address(0), "Invalid storage address");
        storageContract = _storageContract;

        _platformFee = _initialPlatformFee;
        _feeRecipient = _initialFeeRecipient;
        _bifyToken = _initialBifyToken;
        _bifyFee = _initialBifyFee;
    }

    /**
     * @notice Check if the contract is initialized
     * @return Whether the contract is initialized
     */
    function isInitialized() public view returns (bool) {
        return _initialized;
    }

    /**
     * @notice Initialize storage values - called after contract authorization
     * @dev Must be called after the contract has been authorized in storage
     */
    function initialize() public virtual onlyOwner {
        require(!_initialized, "Already initialized");
        _initialized = true;
    }

    /**
     * @notice Modifier to ensure contract is initialized
     */
    modifier whenInitialized() {
        require(_initialized, "Not initialized");
        _;
    }
}
