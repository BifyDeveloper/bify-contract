// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title BifyLaunchpadCore
 * @notice Core contract for the Bify Launchpad system. Handles NFT collection creation, fee management, and core launchpad operations. Should be used via the BifyLaunchpad facade contract for proper authorization and coordination.
 * @dev This contract is part of a modular system and is not intended to be used directly by end users.
 */
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./NFTCollection.sol";
import {BifyLaunchpadLibrary} from "./BifyLaunchpadLibrary.sol";
import "./WhitelistManagerFactory.sol";
import "./IWhitelistManagerExtended.sol";
import "./storage/BifyLaunchpadStorage.sol";
import "./libraries/BifyCollectionRegistry.sol";
import "./libraries/BifyPaymentManager.sol";
import "./libraries/BifyWhitelistManager.sol";
import "./libraries/BifyCollectionFactory.sol";

/**
 * @title IBifyMarketplace
 * @dev Interface for marketplace registration functions
 */
interface IBifyMarketplace {
    function registerLaunchpadCollection(address _collection) external;
}

/**
 * @title BifyLaunchpadCore
 * @dev Core functionality for the launchpad, optimized for contract size
 */
contract BifyLaunchpadCore is Ownable, ReentrancyGuard, Pausable {
    // Storage contract
    address public immutable storageContract;

    // Helper to get the storage contract as a BifyLaunchpadStorage
    function _getStorage()
        internal
        view
        virtual
        returns (BifyLaunchpadStorage)
    {
        return BifyLaunchpadStorage(storageContract);
    }

    // Constants
    bytes32 public constant EMPTY_CATEGORY = bytes32(0);

    // Initialization tracking - simplified to a single flag
    bool private _initialized = false;

    // Events - enhanced for better indexing
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
    event BifyTokenUpdated(address oldToken, address newToken);

    // Event for advanced whitelist integration
    event AdvancedWhitelistEnabled(
        address indexed collection,
        address indexed whitelistManager
    );

    // Events for marketplace registration
    event MarketplaceRegistrationSuccess(address indexed collection);
    event MarketplaceRegistrationFailed(
        address indexed collection,
        string reason
    );

    // Platform fee and token settings
    uint256 private _platformFee;
    address private _feeRecipient;
    address private _bifyToken;
    uint256 private _bifyFee;
    address private _marketplaceAddress;

    /**
     * @dev Constructor - only stores references but doesn't modify storage yet
     * @param _storageContract Address of the BifyLaunchpadStorage contract
     * @param _initialPlatformFee Fee in ETH for collection creation (stored locally until initialization)
     * @param _initialFeeRecipient Address to receive fees (stored locally until initialization)
     * @param _initialBifyToken Address of Bify token contract (stored locally until initialization)
     * @param _initialBifyFee Fee in Bify tokens for collection creation (stored locally until initialization)
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

        // Store values locally for later initialization
        _platformFee = _initialPlatformFee;
        _feeRecipient = _initialFeeRecipient;
        _bifyToken = _initialBifyToken;
        _bifyFee = _initialBifyFee;
    }

    /**
     * @notice Initialize storage values - called after contract authorization
     * @dev Must be called after the contract has been authorized in storage
     * @dev Combined initialization into a single function to save gas and reduce complexity
     */
    function initialize() public virtual onlyOwner {
        require(!_initialized, "Already initialized");

        // Initialize all storage values at once
        _getStorage().setPlatformFee(_platformFee);
        _getStorage().setFeeRecipient(_feeRecipient);

        // Initialize Bify token parameters if token address is provided
        if (_bifyToken != address(0)) {
            _getStorage().setBifyToken(_bifyToken);
            _getStorage().setBifyFee(_bifyFee);
            _getStorage().setAllowBifyPayment(true);
        }

        _initialized = true;
    }

    /**
     * @notice Modifier to ensure contract is initialized
     */
    modifier whenInitialized() {
        require(_initialized, "Not initialized");
        _;
    }

    /**
     * @notice Modifier to ensure caller is owner or authorized operator
     */
    modifier onlyOwnerOrAuthorized() {
        require(
            msg.sender == owner() ||
                _getStorage().authorizedOperators(msg.sender),
            "Not authorized"
        );
        _;
    }

    /**
     * @notice Check if the contract is initialized
     * @return Whether the contract is initialized
     */
    function isInitialized() external view returns (bool) {
        return _initialized;
    }

    /**
     * @notice Creates a new NFT collection with customizable parameters
     * @param _name Collection name
     * @param _symbol Collection symbol
     * @param _maxSupply Maximum supply of the collection
     * @param _royaltyPercentage Royalty percentage (in basis points, e.g. 500 = 5%)
     * @param _baseURI Base URI for the collection metadata
     * @param _mintStartTime Start time for public minting
     * @param _mintEndTime End time for public minting
     * @param _mintPrice Price per NFT during public mint
     * @param _maxMintsPerWallet Maximum number of NFTs an address can mint
     * @param _category Collection category (used for indexing)
     * @param _useBifyPayment Whether to pay fee in Bify tokens
     * @return collection Address of the newly created collection
     */
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
    )
        external
        payable
        whenNotPaused
        nonReentrant
        whenInitialized
        returns (address collection)
    {
        // Validate parameters using library
        BifyLaunchpadLibrary.validateCollectionParams(
            _name,
            _symbol,
            _maxSupply,
            _royaltyPercentage,
            _mintStartTime,
            _mintEndTime
        );

        // Handle payment through library
        BifyPaymentManager.processPayment(
            _useBifyPayment,
            _getStorage().allowBifyPayment(),
            _getStorage().bifyFee(),
            _getStorage().bifyToken(),
            msg.sender,
            _getStorage().feeRecipient(),
            _getStorage().platformFee(),
            msg.value
        );

        // Deploy new collection using factory library
        address collectionAddress = BifyCollectionFactory.createNFTCollection(
            _name,
            _symbol,
            _maxSupply,
            _royaltyPercentage,
            _baseURI,
            _mintStartTime,
            _mintEndTime,
            _mintPrice,
            _maxMintsPerWallet,
            msg.sender
        );

        // Create collection data struct
        BifyLaunchpadLibrary.CollectionData memory data = BifyLaunchpadLibrary
            .createCollectionData(
                msg.sender,
                _name,
                _symbol,
                _maxSupply,
                _royaltyPercentage,
                _mintStartTime,
                _mintEndTime,
                _mintPrice,
                _maxMintsPerWallet
            );

        // Register collection in storage
        _getStorage().setRegisteredCollection(collectionAddress, true);
        _getStorage().addCreatorCollection(msg.sender, collectionAddress);
        _getStorage().addCollection(collectionAddress);
        _getStorage().setCollectionByIndex(
            _getStorage().collectionCount(),
            collectionAddress
        );
        _getStorage().setCollectionData(collectionAddress, data);

        // Add to category if specified
        if (_category != EMPTY_CATEGORY) {
            _getStorage().addCollectionToCategory(_category, collectionAddress);
            _getStorage().incrementCategoryCount(_category);
        }

        // Increment collection count
        _getStorage().incrementCollectionCount();

        // Register with marketplace (emits events on success/failure)
        _registerWithMarketplace(collectionAddress);

        emit CollectionCreated(
            msg.sender,
            collectionAddress,
            _name,
            _symbol,
            _maxSupply,
            _category,
            _getStorage().platformFee()
        );

        return collectionAddress;
    }

    /**
     * @notice Track a mint event for indexing purposes
     * @param _collection Collection address
     * @param _minter Minter address
     * @param _quantity Number of NFTs minted
     * @param _isWhitelistMint Whether this was a whitelist mint
     */
    function trackMint(
        address _collection,
        address _minter,
        uint256 _quantity,
        bool _isWhitelistMint
    ) external {
        require(
            msg.sender == _collection || msg.sender == owner(),
            "Unauthorized"
        );
        require(
            _getStorage().registeredCollections(_collection),
            "Collection not registered"
        );

        NFTCollection collection = NFTCollection(payable(_collection));
        uint256 currentBalance = collection.balanceOf(_minter) - _quantity;

        // Update storage
        uint256 totalMinted = _getStorage().incrementCollectionTotalMinted(
            _collection,
            _quantity
        );

        // If this is a new holder, increment the counter
        if (currentBalance == 0 && _quantity > 0) {
            _getStorage().incrementUniqueHolders(_collection);
        }

        emit MintTracked(
            _collection,
            _minter,
            _quantity,
            totalMinted,
            _isWhitelistMint
        );
    }

    /**
     * @notice Updates the platform fee
     * @param _newFee New fee amount
     */
    function updatePlatformFee(uint256 _newFee) external onlyOwnerOrAuthorized {
        uint256 oldFee = _getStorage().platformFee();
        _getStorage().setPlatformFee(_newFee);
        emit PlatformFeeUpdated(oldFee, _newFee);
    }

    /**
     * @notice Updates the Bify token fee
     * @param _newFee New fee amount
     */
    function updateBifyFee(uint256 _newFee) external onlyOwnerOrAuthorized {
        uint256 oldFee = _getStorage().bifyFee();
        _getStorage().setBifyFee(_newFee);
        emit BifyFeeUpdated(oldFee, _newFee);
    }

    /**
     * @notice Updates the fee recipient
     * @param _newRecipient New recipient address
     */
    function updateFeeRecipient(
        address _newRecipient
    ) external onlyOwnerOrAuthorized {
        require(_newRecipient != address(0), "Invalid address");
        address oldRecipient = _getStorage().feeRecipient();
        _getStorage().setFeeRecipient(_newRecipient);
        emit FeeRecipientUpdated(oldRecipient, _newRecipient);
    }

    /**
     * @notice Toggles Bify token payment
     * @param _enabled Whether to enable Bify payment
     */
    function toggleBifyPayment(bool _enabled) external onlyOwnerOrAuthorized {
        _getStorage().setAllowBifyPayment(_enabled);
        emit BifyPaymentToggled(_enabled);
    }

    /**
     * @notice Updates the Bify token address
     * @param _token New Bify token address
     */
    function setBifyToken(address _token) external onlyOwner {
        require(_token != address(0), "Not a valid address");
        address oldAddress = address(_getStorage().bifyToken());
        _getStorage().setBifyToken(_token);
        emit BifyTokenUpdated(oldAddress, _token);
    }

    /**
     * @notice Set the marketplace address for automatic collection registration
     * @param _marketplace Address of the BifyMarketplace contract
     */
    function setMarketplaceAddress(address _marketplace) external onlyOwner {
        require(_marketplace != address(0), "Invalid marketplace address");
        _marketplaceAddress = _marketplace;
    }

    /**
     * @notice Get the current marketplace address
     * @return The marketplace address
     */
    function getMarketplaceAddress() external view returns (address) {
        return _marketplaceAddress;
    }

    /**
     * @notice Pauses collection creation
     */
    function pause() external onlyOwnerOrAuthorized {
        _pause();
    }

    /**
     * @notice Unpauses collection creation
     */
    function unpause() external onlyOwnerOrAuthorized {
        _unpause();
    }

    /**
     * @notice Emergency withdrawal in case ETH gets stuck
     */
    function emergencyWithdraw() external onlyOwnerOrAuthorized {
        uint256 balance = address(this).balance;
        require(balance > 0, "No balance to withdraw");
        (bool success, ) = owner().call{value: balance}("");
        require(success, "Withdrawal failed");
    }

    /**
     * @notice Emergency withdrawal of any ERC20 tokens
     * @param _token Token address
     */
    function emergencyWithdrawToken(
        address _token
    ) external onlyOwnerOrAuthorized {
        IERC20 token = IERC20(_token);
        uint256 balance = token.balanceOf(address(this));
        require(balance > 0, "No tokens to withdraw");
        token.transfer(owner(), balance);
    }

    /**
     * @notice Set WhitelistManagerFactory address
     * @param _factory Address of the WhitelistManagerFactory
     */
    function setWhitelistManagerFactory(address _factory) external onlyOwner {
        require(_factory != address(0), "Invalid factory address");
        require(_factory.code.length > 0, "Not a contract");
        _getStorage().setWhitelistManagerFactory(_factory);
    }

    /**
     * @notice Create a new NFT collection with optional advanced whitelist support
     * @param _creator Original creator address (not msg.sender)
     * @param _name Collection name
     * @param _symbol Collection symbol
     * @param _baseURI Base URI for the collection
     * @param _maxSupply Maximum supply for the collection
     * @param _royaltyFee Royalty fee in basis points
     * @param _category Category of the collection
     * @param _enableAdvancedWhitelist Whether to enable advanced whitelist
     * @param _whitelistName Name for the whitelist (if advanced whitelist is enabled)
     * @param _useBifyPayment Whether to pay fee in Bify tokens
     * @return collectionAddress Address of the created collection
     */
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
    )
        external
        payable
        whenNotPaused
        nonReentrant
        whenInitialized
        returns (address collectionAddress)
    {
        // Only authorized callers can specify a creator
        require(
            msg.sender == owner() ||
                _getStorage().authorizedOperators(msg.sender),
            "Not authorized to specify creator"
        );

        // Handle payment through library
        BifyPaymentManager.processPayment(
            _useBifyPayment,
            _getStorage().allowBifyPayment(),
            _getStorage().bifyFee(),
            _getStorage().bifyToken(),
            _creator,
            _getStorage().feeRecipient(),
            _getStorage().platformFee(),
            msg.value
        );

        // Create collection using factory library
        collectionAddress = BifyCollectionFactory.createWhitelistCollection(
            _name,
            _symbol,
            _maxSupply,
            _royaltyFee,
            _baseURI,
            _creator,
            NFTCollection.RevealStrategy.STANDARD // Default to standard reveal
        );

        // Create whitelist manager if requested
        address whitelistContract = address(0);
        if (_enableAdvancedWhitelist) {
            address factory = _getStorage().whitelistManagerFactory();
            require(factory != address(0), "Factory not set");
            WhitelistManagerFactory whitelistFactory = WhitelistManagerFactory(
                factory
            );
            whitelistContract = whitelistFactory.createWhitelistManagerForOwner(
                _whitelistName,
                _creator
            );
        }

        // Create collection data in storage
        BifyLaunchpadLibrary.CollectionData memory data = BifyLaunchpadLibrary
            .CollectionData({
                creator: _creator,
                name: _name,
                symbol: _symbol,
                maxSupply: _maxSupply,
                royaltyPercentage: _royaltyFee,
                createdAt: block.timestamp,
                whitelistEnabled: _enableAdvancedWhitelist,
                whitelistContract: whitelistContract,
                whitelistPhase: BifyLaunchpadLibrary.LaunchPhase({
                    startTime: 0,
                    endTime: 0,
                    price: 0,
                    maxPerWallet: 0,
                    active: false
                }),
                publicPhase: BifyLaunchpadLibrary.LaunchPhase({
                    startTime: 0,
                    endTime: 0,
                    price: 0,
                    maxPerWallet: 0,
                    active: false
                }),
                deployed: true,
                totalMinted: 0,
                uniqueHolders: 0
            });

        // Update storage contract
        _getStorage().setCollectionData(collectionAddress, data);
        _getStorage().setRegisteredCollection(collectionAddress, true);
        _getStorage().addCreatorCollection(_creator, collectionAddress);
        _getStorage().addCollection(collectionAddress);

        // Add to category if specified
        if (_category != bytes32(0)) {
            _getStorage().addCollectionToCategory(_category, collectionAddress);
            _getStorage().incrementCategoryCount(_category);
        }

        // Increment collection count
        _getStorage().incrementCollectionCount();
        _getStorage().setCollectionByIndex(
            _getStorage().collectionCount(),
            collectionAddress
        );

        // Register with marketplace if address is set (emits events on success/failure)
        _registerWithMarketplace(collectionAddress);

        // Emit events
        emit CollectionCreated(
            _creator,
            collectionAddress,
            _name,
            _symbol,
            _maxSupply,
            _category,
            _getStorage().platformFee()
        );

        if (_enableAdvancedWhitelist) {
            emit AdvancedWhitelistEnabled(collectionAddress, whitelistContract);
        }

        return collectionAddress;
    }

    /**
     * @notice Updates royalty information for a collection
     * @param _collection Collection address
     * @param _royaltyPercentage New royalty percentage (in basis points)
     */
    function updateRoyaltyInfo(
        address _collection,
        uint96 _royaltyPercentage
    ) external {
        // Get collection data to verify creator
        (address creator, , , , , , , , , , , , ) = _getStorage()
            .collectionsData(_collection);

        require(msg.sender == creator || msg.sender == owner(), "Unauthorized");
        require(
            _getStorage().registeredCollections(_collection),
            "Collection not registered"
        );

        // Update the NFT collection contract
        NFTCollection(payable(_collection)).setDefaultRoyalty(
            creator,
            _royaltyPercentage
        );
    }

    /**
     * @notice Get the initial platform fee
     * @return The platform fee
     */
    function getInitialPlatformFee() external view returns (uint256) {
        return _platformFee;
    }

    /**
     * @notice Get the initial fee recipient
     * @return The fee recipient address
     */
    function getInitialFeeRecipient() external view returns (address) {
        return _feeRecipient;
    }

    /**
     * @notice Get the initial Bify token address
     * @return The Bify token address
     */
    function getInitialBifyToken() external view returns (address) {
        return _bifyToken;
    }

    /**
     * @notice Get the initial Bify fee
     * @return The Bify fee
     */
    function getInitialBifyFee() external view returns (uint256) {
        return _bifyFee;
    }

    /**
     * @notice Creates a new NFT collection where creator is explicitly specified
     * @dev This function allows the facade contract to pass the original sender as creator
     * @param _creator Original creator address (not msg.sender)
     * @param _name Collection name
     * @param _symbol Collection symbol
     * @param _maxSupply Maximum supply of the collection
     * @param _royaltyPercentage Royalty percentage (in basis points, e.g. 500 = 5%)
     * @param _baseURI Base URI for the collection metadata
     * @param _mintStartTime Start time for public minting
     * @param _mintEndTime End time for public minting
     * @param _mintPrice Price per NFT during public mint
     * @param _maxMintsPerWallet Maximum number of NFTs an address can mint
     * @param _category Collection category (used for indexing)
     * @param _useBifyPayment Whether to pay fee in Bify tokens
     * @return collection Address of the newly created collection
     */
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
    )
        external
        payable
        whenNotPaused
        nonReentrant
        whenInitialized
        returns (address collection)
    {
        // Only authorized callers can specify a creator
        require(
            msg.sender == owner() ||
                _getStorage().authorizedOperators(msg.sender),
            "Not authorized to specify creator"
        );

        // Validate parameters using library
        BifyLaunchpadLibrary.validateCollectionParams(
            _name,
            _symbol,
            _maxSupply,
            _royaltyPercentage,
            _mintStartTime,
            _mintEndTime
        );

        // Handle payment through library
        BifyPaymentManager.processPayment(
            _useBifyPayment,
            _getStorage().allowBifyPayment(),
            _getStorage().bifyFee(),
            _getStorage().bifyToken(),
            _creator, // Use creator for payment processing
            _getStorage().feeRecipient(),
            _getStorage().platformFee(),
            msg.value
        );

        // Deploy new collection using factory library
        address collectionAddress = BifyCollectionFactory.createNFTCollection(
            _name,
            _symbol,
            _maxSupply,
            _royaltyPercentage,
            _baseURI,
            _mintStartTime,
            _mintEndTime,
            _mintPrice,
            _maxMintsPerWallet,
            _creator // Pass creator to collection
        );

        // Create collection data struct
        BifyLaunchpadLibrary.CollectionData memory data = BifyLaunchpadLibrary
            .createCollectionData(
                _creator, // Use creator address here instead of msg.sender
                _name,
                _symbol,
                _maxSupply,
                _royaltyPercentage,
                _mintStartTime,
                _mintEndTime,
                _mintPrice,
                _maxMintsPerWallet
            );

        // Register collection in storage
        _getStorage().setRegisteredCollection(collectionAddress, true);
        _getStorage().addCreatorCollection(_creator, collectionAddress);
        _getStorage().addCollection(collectionAddress);
        _getStorage().setCollectionByIndex(
            _getStorage().collectionCount(),
            collectionAddress
        );
        _getStorage().setCollectionData(collectionAddress, data);

        // Add to category if specified
        if (_category != EMPTY_CATEGORY) {
            _getStorage().addCollectionToCategory(_category, collectionAddress);
            _getStorage().incrementCategoryCount(_category);
        }

        // Increment collection count
        _getStorage().incrementCollectionCount();

        // Register with marketplace if address is set (emits events on success/failure)
        _registerWithMarketplace(collectionAddress);

        emit CollectionCreated(
            _creator,
            collectionAddress,
            _name,
            _symbol,
            _maxSupply,
            _category,
            _getStorage().platformFee()
        );

        return collectionAddress;
    }

    /**
     * @notice Helper function to check if user is authorized for a collection
     * @param _collection Collection address to check
     * @param _user User address to check
     * @return True if user is authorized for the collection
     */
    function isAuthorizedForCollection(
        address _collection,
        address _user
    ) public view virtual returns (bool) {
        return
            _getStorage().isCollectionCreator(_collection, _user) ||
            _user == owner();
    }

    /**
     * @notice Internal function to register a collection with the marketplace
     * @param _collection Collection address to register
     * @return success Whether the registration was successful
     */
    function _registerWithMarketplace(
        address _collection
    ) internal returns (bool success) {
        if (_marketplaceAddress != address(0)) {
            try
                IBifyMarketplace(_marketplaceAddress)
                    .registerLaunchpadCollection(_collection)
            {
                emit MarketplaceRegistrationSuccess(_collection);
                return true;
            } catch Error(string memory reason) {
                emit MarketplaceRegistrationFailed(_collection, reason);
                return false;
            } catch (bytes memory /* lowLevelData */) {
                emit MarketplaceRegistrationFailed(
                    _collection,
                    "Unknown error - low level failure"
                );
                return false;
            }
        }
        return false;
    }

    /**
     * @notice Register a whitelist collection that was created externally
     * @param _collectionAddress Address of the already deployed collection
     * @param _creator Address of the collection creator
     * @param _name Collection name
     * @param _symbol Collection symbol
     * @param _maxSupply Maximum supply for the collection
     * @param _royaltyFee Royalty fee in basis points
     * @param _category Category of the collection
     * @param _enableAdvancedWhitelist Whether to enable advanced whitelist
     * @param _whitelistName Name for the whitelist
     */
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
    ) external {
        // Only authorized callers can register collections
        require(
            msg.sender == owner() ||
                _getStorage().authorizedOperators(msg.sender),
            "Not authorized to register collection"
        );

        // Create whitelist manager if requested
        address whitelistContract = address(0);
        if (_enableAdvancedWhitelist) {
            address factory = _getStorage().whitelistManagerFactory();
            require(factory != address(0), "Factory not set");
            WhitelistManagerFactory whitelistFactory = WhitelistManagerFactory(
                factory
            );
            whitelistContract = whitelistFactory.createWhitelistManager(
                _whitelistName
            );
        }

        // Create collection data in storage
        BifyLaunchpadLibrary.CollectionData memory data = BifyLaunchpadLibrary
            .CollectionData({
                creator: _creator,
                name: _name,
                symbol: _symbol,
                maxSupply: _maxSupply,
                royaltyPercentage: _royaltyFee,
                createdAt: block.timestamp,
                whitelistEnabled: _enableAdvancedWhitelist,
                whitelistContract: whitelistContract,
                whitelistPhase: BifyLaunchpadLibrary.LaunchPhase({
                    startTime: 0,
                    endTime: 0,
                    price: 0,
                    maxPerWallet: 0,
                    active: false
                }),
                publicPhase: BifyLaunchpadLibrary.LaunchPhase({
                    startTime: 0,
                    endTime: 0,
                    price: 0,
                    maxPerWallet: 0,
                    active: false
                }),
                deployed: true,
                totalMinted: 0,
                uniqueHolders: 0
            });

        // Update storage contract
        _getStorage().setCollectionData(_collectionAddress, data);
        _getStorage().setRegisteredCollection(_collectionAddress, true);
        _getStorage().addCreatorCollection(_creator, _collectionAddress);
        _getStorage().addCollection(_collectionAddress);

        // Add to category if specified
        if (_category != bytes32(0)) {
            _getStorage().addCollectionToCategory(
                _category,
                _collectionAddress
            );
            _getStorage().incrementCategoryCount(_category);
        }

        // Increment collection count
        _getStorage().incrementCollectionCount();

        // Emit events
        emit CollectionCreated(
            _creator,
            _collectionAddress,
            _name,
            _symbol,
            _maxSupply,
            _category,
            _getStorage().platformFee()
        );

        if (_enableAdvancedWhitelist) {
            emit AdvancedWhitelistEnabled(
                _collectionAddress,
                whitelistContract
            );
        }
    }
}
