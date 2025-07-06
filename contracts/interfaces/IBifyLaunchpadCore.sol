// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IBifyLaunchpadCore
 * @dev Interface for BifyLaunchpadCore
 */
interface IBifyLaunchpadCore {
    event CollectionCreated(
        address indexed creator,
        address indexed collection,
        string name,
        string symbol,
        uint256 maxSupply,
        bytes32 indexed category,
        uint256 platformFee
    );

    event WhitelistEnabled(
        address indexed collection,
        address whitelistContract,
        uint256 startTime,
        uint256 endTime,
        uint256 price
    );

    event PhaseUpdated(
        address indexed collection,
        bool isWhitelistPhase,
        uint256 startTime,
        uint256 endTime,
        uint256 price
    );

    event MintTracked(
        address indexed collection,
        address indexed minter,
        uint256 quantity,
        uint256 totalMinted,
        bool isWhitelistMint
    );

    event PlatformFeeUpdated(uint256 oldFee, uint256 newFee);
    event BifyFeeUpdated(uint256 oldFee, uint256 newFee);
    event FeeRecipientUpdated(address oldRecipient, address newRecipient);
    event BifyPaymentToggled(bool enabled);
    event AdvancedWhitelistEnabled(
        address indexed collection,
        address indexed whitelistManager
    );

    function createCollection(
        string memory _name,
        string memory _symbol,
        uint256 _maxSupply,
        uint96 _royaltyPercentage,
        string memory _baseURI,
        uint256 _mintStartTime,
        uint256 _mintEndTime,
        uint256 _mintPrice,
        uint256 _maxMintsPerWallet,
        bytes32 _category,
        bool _useBifyPayment
    ) external payable returns (address);

    function createCollectionWithCreator(
        address _creator,
        string memory _name,
        string memory _symbol,
        uint256 _maxSupply,
        uint96 _royaltyPercentage,
        string memory _baseURI,
        uint256 _mintStartTime,
        uint256 _mintEndTime,
        uint256 _mintPrice,
        uint256 _maxMintsPerWallet,
        bytes32 _category,
        bool _useBifyPayment
    ) external payable returns (address);

    function createCollectionWithWhitelist(
        address _creator,
        string memory _name,
        string memory _symbol,
        string memory _baseURI,
        uint256 _maxSupply,
        uint96 _royaltyFee,
        bytes32 _category,
        bool _enableAdvancedWhitelist,
        string memory _whitelistName,
        bool _useBifyPayment
    ) external payable returns (address);

    function updateRoyaltyInfo(
        address _collection,
        uint96 _royaltyPercentage
    ) external;

    function trackMint(
        address _collection,
        address _minter,
        uint256 _quantity,
        bool _isWhitelistMint
    ) external;

    function updatePlatformFee(uint256 _newFee) external;
    function updateBifyFee(uint256 _newFee) external;
    function updateFeeRecipient(address _newRecipient) external;
    function toggleBifyPayment(bool _enabled) external;
    function pause() external;
    function unpause() external;
    function emergencyWithdraw() external;
    function emergencyWithdrawToken(address _token) external;
    function setWhitelistManagerFactory(address _factory) external;

    /**
     * @notice Helper function to check if user is authorized for a collection
     */
    function isAuthorizedForCollection(
        address _collection,
        address _user
    ) external view returns (bool);

    // Added functions for whitelist collections with reveal strategy
    function registerWhitelistCollection(
        address _collectionAddress,
        address _creator,
        string memory _name,
        string memory _symbol,
        uint256 _maxSupply,
        uint96 _royaltyFee,
        bytes32 _category,
        bool _enableAdvancedWhitelist,
        string memory _whitelistName
    ) external;

    // Fee getter functions
    function getInitialPlatformFee() external view returns (uint256);
    function getInitialFeeRecipient() external view returns (address);
    function getInitialBifyToken() external view returns (address);
    function getInitialBifyFee() external view returns (uint256);

    // Add storageContract accessor to the interface
    function storageContract() external view returns (address);
}
