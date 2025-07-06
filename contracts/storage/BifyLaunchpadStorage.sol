// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../BifyLaunchpadLibrary.sol";

/**
 * @title BifyLaunchpadStorage
 * @dev Storage contract for BifyLaunchpad, isolated to reduce contract size
 */
contract BifyLaunchpadStorage is Ownable {
    uint256 public platformFee;
    address public feeRecipient;
    IERC20 public bifyToken;
    bool public allowBifyPayment;
    uint256 public bifyFee;

    mapping(address => address[]) public creatorCollections;
    mapping(address => bool) public registeredCollections;
    address[] public allCollections;

    mapping(address => BifyLaunchpadLibrary.CollectionData)
        public collectionsData;
    mapping(uint256 => address) public collectionByIndex;
    uint256 public collectionCount;

    mapping(bytes32 => address[]) public collectionsByCategory;
    mapping(bytes32 => uint256) public categoryCount;

    bytes32 public constant EMPTY_CATEGORY = bytes32(0);

    address public whitelistManagerFactory;

    mapping(address => bool) public authorizedOperators;

    /**
     * @dev Modifier to restrict access to authorized operators
     */
    modifier onlyAuthorized() {
        require(
            msg.sender == owner() || authorizedOperators[msg.sender],
            "Not authorized"
        );
        _;
    }

    /**
     * @dev Constructor - initialize with default values
     */
    constructor() {
        authorizedOperators[msg.sender] = true;
    }

    /**
     * @notice Set or remove an authorized operator
     * @param operator Operator address
     * @param authorized Authorization status
     */
    function setAuthorizedOperator(
        address operator,
        bool authorized
    ) external onlyOwner {
        authorizedOperators[operator] = authorized;
    }

    /**
     * @notice Update platform fee
     * @param _platformFee New platform fee
     */
    function setPlatformFee(uint256 _platformFee) external onlyAuthorized {
        platformFee = _platformFee;
    }

    /**
     * @notice Update fee recipient
     * @param _feeRecipient New fee recipient
     */
    function setFeeRecipient(address _feeRecipient) external onlyAuthorized {
        require(_feeRecipient != address(0), "Invalid address");
        feeRecipient = _feeRecipient;
    }

    /**
     * @notice Set Bify token
     * @param _bifyToken New Bify token address
     */
    function setBifyToken(address _bifyToken) external onlyAuthorized {
        require(_bifyToken != address(0), "Invalid address");
        bifyToken = IERC20(_bifyToken);
    }

    /**
     * @notice Update Bify fee
     * @param _bifyFee New Bify fee
     */
    function setBifyFee(uint256 _bifyFee) external onlyAuthorized {
        bifyFee = _bifyFee;
    }

    /**
     * @notice Toggle Bify payment
     * @param _allowBifyPayment Whether to allow Bify payments
     */
    function setAllowBifyPayment(
        bool _allowBifyPayment
    ) external onlyAuthorized {
        allowBifyPayment = _allowBifyPayment;
    }

    /**
     * @notice Set WhitelistManagerFactory
     * @param _factory Factory address
     */
    function setWhitelistManagerFactory(
        address _factory
    ) external onlyAuthorized {
        require(_factory != address(0), "Invalid factory address");
        whitelistManagerFactory = _factory;
    }

    /**
     * @notice Sets a collection as registered
     * @param collection Collection address
     * @param registered Registration status
     */
    function setRegisteredCollection(
        address collection,
        bool registered
    ) external onlyAuthorized {
        registeredCollections[collection] = registered;
    }

    /**
     * @notice Add a collection to a creator's list
     * @param creator Creator address
     * @param collection Collection address
     */
    function addCreatorCollection(
        address creator,
        address collection
    ) external onlyAuthorized {
        creatorCollections[creator].push(collection);
    }

    /**
     * @notice Add a collection to the global list
     * @param collection Collection address
     */
    function addCollection(address collection) external onlyAuthorized {
        allCollections.push(collection);
    }

    /**
     * @notice Set collection by index
     * @param index Collection index
     * @param collection Collection address
     */
    function setCollectionByIndex(
        uint256 index,
        address collection
    ) external onlyAuthorized {
        collectionByIndex[index] = collection;
    }

    /**
     * @notice Increment collection count
     * @return The new collection count
     */
    function incrementCollectionCount()
        external
        onlyAuthorized
        returns (uint256)
    {
        collectionCount++;
        return collectionCount;
    }

    /**
     * @notice Add a collection to a category
     * @param category Category bytes32
     * @param collection Collection address
     */
    function addCollectionToCategory(
        bytes32 category,
        address collection
    ) external onlyAuthorized {
        collectionsByCategory[category].push(collection);
    }

    /**
     * @notice Increment category count
     * @param category Category bytes32
     * @return The new category count
     */
    function incrementCategoryCount(
        bytes32 category
    ) external onlyAuthorized returns (uint256) {
        categoryCount[category]++;
        return categoryCount[category];
    }

    /**
     * @notice Set collection data
     * @param collection Collection address
     * @param data Collection data
     */
    function setCollectionData(
        address collection,
        BifyLaunchpadLibrary.CollectionData calldata data
    ) external onlyAuthorized {
        collectionsData[collection] = data;
    }

    /**
     * @notice Update collection total minted
     * @param collection Collection address
     * @param quantity Quantity to add
     * @return The new total minted
     */
    function incrementCollectionTotalMinted(
        address collection,
        uint256 quantity
    ) external onlyAuthorized returns (uint256) {
        collectionsData[collection].totalMinted += quantity;
        return collectionsData[collection].totalMinted;
    }

    /**
     * @notice Increment collection unique holders
     * @param collection Collection address
     * @return The new unique holders count
     */
    function incrementUniqueHolders(
        address collection
    ) external onlyAuthorized returns (uint256) {
        collectionsData[collection].uniqueHolders++;
        return collectionsData[collection].uniqueHolders;
    }

    /**
     * @notice Check if an address is the creator of a collection
     * @param _collection Collection address
     * @param _address Address to check
     * @return True if the address is the creator of the collection
     */
    function isCollectionCreator(
        address _collection,
        address _address
    ) external view returns (bool) {
        return collectionsData[_collection].creator == _address;
    }
}
