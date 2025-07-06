// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./interfaces/IBifyLaunchpadCore.sol";
import "./interfaces/IBifyLaunchpadPhase.sol";
import "./interfaces/IBifyLaunchpadQuery.sol";
import "./storage/BifyLaunchpadStorage.sol";
import "./BifyLaunchpadCore.sol";
import "./BifyLaunchpadPhase.sol";
import "./libraries/BifyCollectionFactory.sol";
import "./NFTCollection.sol";

/**
 * @title BifyLaunchpad
 * @notice Facade and entry point for the Bify Launchpad system. Coordinates between core, phase, and query components, and enforces authorization for all launchpad operations.
 * @dev End users and dApps should interact with this contract for all launchpad-related actions.
 */
contract BifyLaunchpad is Ownable, ReentrancyGuard {
    // Implementation contracts
    IBifyLaunchpadCore public immutable coreContract;
    IBifyLaunchpadPhase public immutable phaseContract;
    IBifyLaunchpadQuery public queryContract;

    // Storage reference - needed to check authorizations directly
    BifyLaunchpadStorage public immutable storageContract;

    // Events
    event QueryContractUpdated(address indexed newQueryContract);

    /**
     * @dev Constructor - stores the addresses of the implementation contracts
     * @param _core Address of the BifyLaunchpadCore contract
     * @param _phase Address of the BifyLaunchpadPhase contract
     * @param _query Address of the BifyLaunchpadQuery contract
     * @param _storage Address of the BifyLaunchpadStorage contract
     */
    constructor(
        address _core,
        address _phase,
        address _query,
        address _storage
    ) {
        require(_core != address(0), "Invalid core address");
        require(_phase != address(0), "Invalid phase address");
        require(_query != address(0), "Invalid query address");
        require(_storage != address(0), "Invalid storage address");

        // Initialize storage reference
        BifyLaunchpadStorage storageContractTemp = BifyLaunchpadStorage(
            _storage
        );

        // Verify this contract is authorized (if already authorized)
        // But don't try to authorize itself
        if (storageContractTemp.authorizedOperators(address(this))) {
            // Already authorized - this is good
        } else {
            // Not authorized yet - that's fine, will be handled in deployment script
        }

        coreContract = IBifyLaunchpadCore(_core);
        phaseContract = IBifyLaunchpadPhase(_phase);
        queryContract = IBifyLaunchpadQuery(_query);
        storageContract = storageContractTemp;
    }

    // ========== CORE FUNCTIONS ==========

    /**
     * @notice Creates a new NFT collection with customizable parameters
     * @dev This implementation properly forwards the original sender as the creator
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
    ) external payable nonReentrant returns (address) {
        // Use the fixed function that properly passes the creator address
        return
            coreContract.createCollectionWithCreator{value: msg.value}(
                msg.sender, // Pass the original sender as creator
                _name,
                _symbol,
                _maxSupply,
                _royaltyPercentage,
                _baseURI,
                _mintStartTime,
                _mintEndTime,
                _mintPrice,
                _maxMintsPerWallet,
                _category,
                _useBifyPayment
            );
    }

    function createCollectionWithWhitelist(
        string memory _name,
        string memory _symbol,
        string memory _baseURI,
        uint256 _maxSupply,
        uint96 _royaltyFee,
        bytes32 _category,
        bool _enableAdvancedWhitelist,
        string memory _whitelistName,
        bool _useBifyPayment
    ) external payable nonReentrant returns (address) {
        return
            coreContract.createCollectionWithWhitelist{value: msg.value}(
                msg.sender, // Pass the original sender as creator
                _name,
                _symbol,
                _baseURI,
                _maxSupply,
                _royaltyFee,
                _category,
                _enableAdvancedWhitelist,
                _whitelistName,
                _useBifyPayment
            );
    }

    function createCollectionWithWhitelistAndRevealStrategy(
        string memory _name,
        string memory _symbol,
        string memory _baseURI,
        uint256 _maxSupply,
        uint96 _royaltyFee,
        bytes32 _category,
        bool _enableAdvancedWhitelist,
        string memory _whitelistName,
        uint8 _revealStrategy
    ) external payable nonReentrant returns (address) {
        // Convert uint8 _revealStrategy to NFTCollection.RevealStrategy
        NFTCollection.RevealStrategy strategy = NFTCollection.RevealStrategy(
            _revealStrategy
        );

        // Process payment
        uint256 platformFee = storageContract.platformFee();
        require(msg.value >= platformFee, "Insufficient payment");

        // Forward fee to recipient
        address feeRecipient = storageContract.feeRecipient();
        (bool success, ) = feeRecipient.call{value: platformFee}("");
        require(success, "Fee transfer failed");

        // Refund excess payment
        uint256 refund = msg.value - platformFee;
        if (refund > 0) {
            (bool refundSuccess, ) = msg.sender.call{value: refund}("");
            require(refundSuccess, "Refund transfer failed");
        }

        // Deploy collection with factory
        address collectionAddress = BifyCollectionFactory
            .createWhitelistCollection(
                _name,
                _symbol,
                _maxSupply,
                _royaltyFee,
                _baseURI,
                msg.sender,
                strategy
            );

        // Register collection in the core contract
        coreContract.registerWhitelistCollection(
            collectionAddress,
            msg.sender, // Pass the original sender as creator
            _name,
            _symbol,
            _maxSupply,
            _royaltyFee,
            _category,
            _enableAdvancedWhitelist,
            _whitelistName
        );

        return collectionAddress;
    }

    function updateRoyaltyInfo(
        address _collection,
        uint96 _royaltyPercentage
    ) external {
        coreContract.updateRoyaltyInfo(_collection, _royaltyPercentage);
    }

    function trackMint(
        address _collection,
        address _minter,
        uint256 _quantity,
        bool _isWhitelistMint
    ) external {
        // Verify this is being called by the collection contract or an admin
        require(
            msg.sender == _collection ||
                storageContract.isCollectionCreator(_collection, msg.sender) ||
                msg.sender == owner(),
            "Not authorized"
        );

        coreContract.trackMint(
            _collection,
            _minter,
            _quantity,
            _isWhitelistMint
        );
    }

    function updatePlatformFee(uint256 _newFee) external onlyOwner {
        coreContract.updatePlatformFee(_newFee);
    }

    function updateBifyFee(uint256 _newFee) external onlyOwner {
        coreContract.updateBifyFee(_newFee);
    }

    function updateFeeRecipient(address _newRecipient) external onlyOwner {
        coreContract.updateFeeRecipient(_newRecipient);
    }

    function toggleBifyPayment(bool _enabled) external onlyOwner {
        coreContract.toggleBifyPayment(_enabled);
    }

    function pause() external onlyOwner {
        coreContract.pause();
    }

    function unpause() external onlyOwner {
        coreContract.unpause();
    }

    function emergencyWithdraw() external onlyOwner {
        coreContract.emergencyWithdraw();
    }

    function emergencyWithdrawToken(address _token) external onlyOwner {
        coreContract.emergencyWithdrawToken(_token);
    }

    function setWhitelistManagerFactory(address _factory) external onlyOwner {
        coreContract.setWhitelistManagerFactory(_factory);
    }

    // ========== PHASE FUNCTIONS ==========

    /**
     * @notice Sets the whitelist phase for a collection
     * @param _collection Collection address
     * @param _startTime Start time of the whitelist phase
     * @param _endTime End time of the whitelist phase
     * @param _price Price per NFT during the whitelist phase
     * @param _maxPerWallet Maximum number of NFTs an address can mint during the whitelist phase
     */
    function setWhitelistPhase(
        address _collection,
        uint256 _startTime,
        uint256 _endTime,
        uint256 _price,
        uint256 _maxPerWallet
    ) external {
        // Verify authorization
        require(
            storageContract.isCollectionCreator(_collection, msg.sender) ||
                msg.sender == owner(),
            "Not authorized"
        );

        phaseContract.setWhitelistPhase(
            _collection,
            _startTime,
            _endTime,
            _price,
            _maxPerWallet
        );
    }

    /**
     * @notice Sets the public phase for a collection
     * @param _collection Collection address
     * @param _startTime Start time of the public phase
     * @param _endTime End time of the public phase
     * @param _price Price per NFT during the public phase
     * @param _maxPerWallet Maximum number of NFTs an address can mint during the public phase
     */
    function setPublicPhase(
        address _collection,
        uint256 _startTime,
        uint256 _endTime,
        uint256 _price,
        uint256 _maxPerWallet
    ) external {
        // Verify authorization
        require(
            storageContract.isCollectionCreator(_collection, msg.sender) ||
                msg.sender == owner(),
            "Not authorized"
        );

        phaseContract.setPublicPhase(
            _collection,
            _startTime,
            _endTime,
            _price,
            _maxPerWallet
        );
    }

    /**
     * @notice Updates the public phase for a collection
     * @param _collection Collection address
     * @param _startTime Start time of the public phase
     * @param _endTime End time of the public phase
     * @param _price Price per NFT during the public phase
     * @param _maxPerWallet Maximum number of NFTs an address can mint during the public phase
     */
    function updatePublicPhase(
        address _collection,
        uint256 _startTime,
        uint256 _endTime,
        uint256 _price,
        uint256 _maxPerWallet
    ) external {
        // Verify authorization
        require(
            storageContract.isCollectionCreator(_collection, msg.sender) ||
                msg.sender == owner(),
            "Not authorized"
        );

        phaseContract.updatePublicPhase(
            _collection,
            _startTime,
            _endTime,
            _price,
            _maxPerWallet
        );
    }

    /**
     * @notice Updates the whitelist phase for a collection
     * @param _collection Collection address
     * @param _startTime Start time of the whitelist phase
     * @param _endTime End time of the whitelist phase
     * @param _price Price per NFT during the whitelist phase
     * @param _maxPerWallet Maximum number of NFTs an address can mint during the whitelist phase
     */
    function updateWhitelistPhase(
        address _collection,
        uint256 _startTime,
        uint256 _endTime,
        uint256 _price,
        uint256 _maxPerWallet
    ) external {
        // Verify authorization
        require(
            storageContract.isCollectionCreator(_collection, msg.sender) ||
                msg.sender == owner(),
            "Not authorized"
        );

        phaseContract.updateWhitelistPhase(
            _collection,
            _startTime,
            _endTime,
            _price,
            _maxPerWallet
        );
    }

    /**
     * @notice Disables the whitelist phase for a collection
     * @param _collection Collection address
     */
    function disableWhitelistPhase(address _collection) external {
        // Verify authorization
        require(
            storageContract.isCollectionCreator(_collection, msg.sender) ||
                msg.sender == owner(),
            "Not authorized"
        );

        phaseContract.disableWhitelistPhase(_collection);
    }

    /**
     * @notice Disables the public phase for a collection
     * @param _collection Collection address
     */
    function disablePublicPhase(address _collection) external {
        // Verify authorization
        require(
            storageContract.isCollectionCreator(_collection, msg.sender) ||
                msg.sender == owner(),
            "Not authorized"
        );

        phaseContract.disablePublicPhase(_collection);
    }

    /**
     * @notice Configures an advanced whitelist for a collection
     * @param _collection Collection address
     * @param _whitelistManager Whitelist manager address
     */
    function configureAdvancedWhitelist(
        address _collection,
        address _whitelistManager
    ) external {
        // Verify authorization
        require(
            storageContract.isCollectionCreator(_collection, msg.sender) ||
                msg.sender == owner(),
            "Not authorized"
        );

        phaseContract.configureAdvancedWhitelist(
            _collection,
            _whitelistManager
        );
    }

    /**
     * @notice Updates the base URI for a collection
     * @param _collection Collection address
     * @param _newBaseURI New base URI for the collection metadata
     */
    function updateCollectionBaseURI(
        address _collection,
        string memory _newBaseURI
    ) external {
        // Verify authorization
        require(
            storageContract.isCollectionCreator(_collection, msg.sender) ||
                msg.sender == owner(),
            "Not authorized"
        );

        phaseContract.updateCollectionBaseURI(_collection, _newBaseURI);
    }

    /**
     * @notice Toggles active state of whitelist phase
     * @param _collection Collection address
     * @param _active Whether to activate or deactivate
     */
    function toggleWhitelistPhase(address _collection, bool _active) external {
        // Verify authorization
        require(
            isAuthorizedForCollection(_collection, msg.sender),
            "Not authorized"
        );

        phaseContract.toggleWhitelistPhase(_collection, _active);
    }

    /**
     * @notice Toggles active state of public phase
     * @param _collection Collection address
     * @param _active Whether to activate or deactivate
     */
    function togglePublicPhase(address _collection, bool _active) external {
        // Verify authorization
        require(
            isAuthorizedForCollection(_collection, msg.sender),
            "Not authorized"
        );

        phaseContract.togglePublicPhase(_collection, _active);
    }

    // ========== QUERY FUNCTIONS ==========

    /**
     * @notice Gets collections created by a specific creator
     * @param _creator Creator address
     * @return Array of collection addresses
     */
    function getCreatorCollections(
        address _creator
    ) external view returns (address[] memory) {
        return queryContract.getCreatorCollections(_creator);
    }

    /**
     * @notice Gets all collections
     * @param _start Start index
     * @param _limit Limit of collections to return
     * @return Array of collection addresses
     */
    function getAllCollections(
        uint256 _start,
        uint256 _limit
    ) external view returns (address[] memory) {
        return queryContract.getAllCollections(_start, _limit);
    }

    /**
     * @notice Gets collections by category
     * @param _category Collection category
     * @param _start Start index
     * @param _limit Limit of collections to return
     * @return Array of collection addresses
     */
    function getCollectionsByCategory(
        bytes32 _category,
        uint256 _start,
        uint256 _limit
    ) external view returns (address[] memory) {
        return
            queryContract.getCollectionsByCategory(_category, _start, _limit);
    }

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
        return queryContract.getActivePhase(_collection);
    }

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
        return queryContract.getCollectionInfo(_collection);
    }

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
        return queryContract.getCollectionPhases(_collection);
    }

    /**
     * @notice Checks if a user is whitelisted for a collection
     * @param _collection Collection address
     * @param _user User address
     * @return Boolean indicating if the user is whitelisted
     */
    function isWhitelistedUser(
        address _collection,
        address _user
    ) external view returns (bool) {
        return queryContract.isWhitelistedUser(_collection, _user);
    }

    /**
     * @notice Gets platform fee
     * @return Platform fee
     */
    function getPlatformFee() external view returns (uint256) {
        return queryContract.getPlatformFee();
    }

    /**
     * @notice Gets Bify fee
     * @return Bify fee
     */
    function getBifyFee() external view returns (uint256) {
        return queryContract.getBifyFee();
    }

    /**
     * @notice Gets fee recipient
     * @return Fee recipient address
     */
    function getFeeRecipient() external view returns (address) {
        return queryContract.getFeeRecipient();
    }

    /**
     * @notice Checks if Bify payment is allowed
     * @return Boolean indicating if Bify payment is allowed
     */
    function isBifyPaymentAllowed() external view returns (bool) {
        return queryContract.isBifyPaymentAllowed();
    }

    /**
     * @notice Gets whitelist manager for a collection
     * @param _collection Collection address
     * @return Whitelist manager address
     */
    function getWhitelistManager(
        address _collection
    ) external view returns (address) {
        return queryContract.getWhitelistManager(_collection);
    }

    /**
     * @notice Checks if a collection is registered
     * @param _collection Collection address
     * @return Boolean indicating if the collection is registered
     */
    function isCollectionRegistered(
        address _collection
    ) external view returns (bool) {
        return queryContract.isCollectionRegistered(_collection);
    }

    /**
     * @notice Gets total number of collections
     * @return Total number of collections
     */
    function getTotalCollections() external view returns (uint256) {
        return queryContract.getTotalCollections();
    }

    /**
     * @notice Gets category count
     * @param _category Collection category
     * @return Category count
     */
    function getCategoryCount(
        bytes32 _category
    ) external view returns (uint256) {
        return queryContract.getCategoryCount(_category);
    }

    /**
     * @notice Helper function to check if a user is authorized for a collection
     * @param _collection Collection address
     * @param _user User address
     * @return Boolean indicating if the user is authorized
     */
    function isAuthorizedForCollection(
        address _collection,
        address _user
    ) public view returns (bool) {
        // Use the standardized authorization check from core contract
        return coreContract.isAuthorizedForCollection(_collection, _user);
    }

    // ========== ADMIN FUNCTIONS ==========

    /**
     * @notice Update the query contract address
     * @param _queryContract New query contract address
     */
    function updateQueryContract(address _queryContract) external onlyOwner {
        require(_queryContract != address(0), "Invalid query contract address");
        queryContract = IBifyLaunchpadQuery(_queryContract);
        emit QueryContractUpdated(_queryContract);
    }

    // Function to receive Ether
    receive() external payable {}
}
