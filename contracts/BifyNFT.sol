// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "./MarketplaceQuery.sol";

/**
 * @title BifyNFT
 * @dev Contract for standalone NFT creation with enhanced security and query capabilities
 */
contract BifyNFT is
    ERC721,
    ERC721Enumerable,
    ERC721URIStorage,
    ERC2981,
    Ownable,
    ReentrancyGuard,
    Pausable
{
    using Counters for Counters.Counter;
    using Strings for uint256;
    using ECDSA for bytes32;

    // Token counter
    Counters.Counter private _tokenIdCounter;

    // Platform fee settings
    address public feeRecipient;
    uint96 public constant DEFAULT_ROYALTY_FEE = 250; // 2.5% in basis points
    uint256 public constant MAX_ROYALTY_FEE = 1000; // 10% in basis points
    uint256 public constant BASIS_POINTS = 10000; // Standard basis points for calculations

    // Backend signature verification
    address public backendSigner;

    // Marketplace integration
    address public marketplace;

    // Query contract integration
    MarketplaceQuery public queryContract;

    // Admin changes time delay
    uint256 public constant ADMIN_CHANGE_DELAY = 2 days;

    // Pending admin changes
    struct PendingAdminChange {
        address newAddress;
        uint256 effectiveTime;
        bool isPending;
    }

    PendingAdminChange public pendingMarketplaceChange;
    PendingAdminChange public pendingFeeRecipientChange;
    PendingAdminChange public pendingBackendSignerChange;
    PendingAdminChange public pendingQueryContractChange;

    // NFT metadata
    enum AssetType {
        NFT,
        RWA
    }

    struct TokenMetadata {
        bytes32 category;
        uint256 createdAt;
        AssetType assetType;
    }

    // Mappings
    mapping(uint256 => TokenMetadata) private _tokenMetadata;
    mapping(address => uint256[]) private _creatorTokens;
    mapping(uint256 => address) private _tokenCreators;

    // Events
    event NFTMinted(
        uint256 indexed tokenId,
        address indexed creator,
        address indexed owner,
        string tokenURI,
        bytes32 category,
        AssetType assetType
    );

    event MarketplaceAddressUpdated(
        address indexed oldMarketplace,
        address indexed newMarketplace
    );
    event BackendSignerUpdated(
        address indexed oldSigner,
        address indexed newSigner
    );
    event FeeRecipientUpdated(
        address indexed oldRecipient,
        address indexed newRecipient
    );
    event QueryContractUpdated(address indexed newQueryContract);

    event AdminChangeScheduled(
        string changeType,
        address indexed currentAddress,
        address indexed newAddress,
        uint256 effectiveTime
    );

    event AdminChangeApplied(
        string changeType,
        address indexed oldAddress,
        address indexed newAddress
    );

    event AdminChangeCanceled(
        string changeType,
        address indexed currentAddress
    );

    /**
     * @dev Constructor
     * @param name Token name
     * @param symbol Token symbol
     * @param _backendSigner Address authorized to sign minting requests
     * @param _feeRecipient Address to receive fees
     */
    constructor(
        string memory name,
        string memory symbol,
        address _backendSigner,
        address _feeRecipient
    ) ERC721(name, symbol) {
        require(_backendSigner != address(0), "Invalid signer address");
        require(_feeRecipient != address(0), "Invalid fee recipient address");

        backendSigner = _backendSigner;
        feeRecipient = _feeRecipient;

        // Set default royalty
        _setDefaultRoyalty(_feeRecipient, DEFAULT_ROYALTY_FEE);
    }

    /**
     * @dev Pause the contract
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @dev Unpause the contract
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    /**
     * @dev Set the query contract
     * @param _queryContract Query contract address
     */
    function setQueryContract(address _queryContract) external onlyOwner {
        pendingQueryContractChange = PendingAdminChange({
            newAddress: _queryContract,
            effectiveTime: block.timestamp + ADMIN_CHANGE_DELAY,
            isPending: true
        });

        emit AdminChangeScheduled(
            "QueryContract",
            address(queryContract),
            _queryContract,
            pendingQueryContractChange.effectiveTime
        );
    }

    /**
     * @dev Apply pending query contract change
     */
    function applyQueryContractChange() external onlyOwner {
        require(pendingQueryContractChange.isPending, "No pending change");
        require(
            block.timestamp >= pendingQueryContractChange.effectiveTime,
            "Change not ready"
        );

        address oldAddress = address(queryContract);
        queryContract = MarketplaceQuery(pendingQueryContractChange.newAddress);
        pendingQueryContractChange.isPending = false;

        emit AdminChangeApplied(
            "QueryContract",
            oldAddress,
            pendingQueryContractChange.newAddress
        );
        emit QueryContractUpdated(pendingQueryContractChange.newAddress);
    }

    /**
     * @dev Cancel pending query contract change
     */
    function cancelQueryContractChange() external onlyOwner {
        require(pendingQueryContractChange.isPending, "No pending change");

        address currentAddress = address(queryContract);
        pendingQueryContractChange.isPending = false;

        emit AdminChangeCanceled("QueryContract", currentAddress);
    }

    /**
     * @dev Schedule marketplace address change
     * @param _marketplace New marketplace address
     */
    function scheduleMarketplaceChange(
        address _marketplace
    ) external onlyOwner {
        require(_marketplace != address(0), "Invalid marketplace address");

        pendingMarketplaceChange = PendingAdminChange({
            newAddress: _marketplace,
            effectiveTime: block.timestamp + ADMIN_CHANGE_DELAY,
            isPending: true
        });

        emit AdminChangeScheduled(
            "Marketplace",
            marketplace,
            _marketplace,
            pendingMarketplaceChange.effectiveTime
        );
    }

    /**
     * @dev Apply pending marketplace address change
     */
    function applyMarketplaceChange() external onlyOwner {
        require(pendingMarketplaceChange.isPending, "No pending change");
        require(
            block.timestamp >= pendingMarketplaceChange.effectiveTime,
            "Change not ready"
        );

        address oldMarketplace = marketplace;
        marketplace = pendingMarketplaceChange.newAddress;
        pendingMarketplaceChange.isPending = false;

        emit AdminChangeApplied("Marketplace", oldMarketplace, marketplace);
        emit MarketplaceAddressUpdated(oldMarketplace, marketplace);
    }

    /**
     * @dev Cancel pending marketplace address change
     */
    function cancelMarketplaceChange() external onlyOwner {
        require(pendingMarketplaceChange.isPending, "No pending change");

        pendingMarketplaceChange.isPending = false;

        emit AdminChangeCanceled("Marketplace", marketplace);
    }

    /**
     * @dev Schedule backend signer address change
     * @param _backendSigner New backend signer address
     */
    function scheduleBackendSignerChange(
        address _backendSigner
    ) external onlyOwner {
        require(_backendSigner != address(0), "Invalid signer address");

        pendingBackendSignerChange = PendingAdminChange({
            newAddress: _backendSigner,
            effectiveTime: block.timestamp + ADMIN_CHANGE_DELAY,
            isPending: true
        });

        emit AdminChangeScheduled(
            "BackendSigner",
            backendSigner,
            _backendSigner,
            pendingBackendSignerChange.effectiveTime
        );
    }

    /**
     * @dev Apply pending backend signer address change
     */
    function applyBackendSignerChange() external onlyOwner {
        require(pendingBackendSignerChange.isPending, "No pending change");
        require(
            block.timestamp >= pendingBackendSignerChange.effectiveTime,
            "Change not ready"
        );

        address oldSigner = backendSigner;
        backendSigner = pendingBackendSignerChange.newAddress;
        pendingBackendSignerChange.isPending = false;

        emit AdminChangeApplied("BackendSigner", oldSigner, backendSigner);
        emit BackendSignerUpdated(oldSigner, backendSigner);
    }

    /**
     * @dev Cancel pending backend signer address change
     */
    function cancelBackendSignerChange() external onlyOwner {
        require(pendingBackendSignerChange.isPending, "No pending change");

        pendingBackendSignerChange.isPending = false;

        emit AdminChangeCanceled("BackendSigner", backendSigner);
    }

    /**
     * @dev Schedule fee recipient address change
     * @param _feeRecipient New fee recipient address
     */
    function scheduleFeeRecipientChange(
        address _feeRecipient
    ) external onlyOwner {
        require(_feeRecipient != address(0), "Invalid fee recipient address");

        pendingFeeRecipientChange = PendingAdminChange({
            newAddress: _feeRecipient,
            effectiveTime: block.timestamp + ADMIN_CHANGE_DELAY,
            isPending: true
        });

        emit AdminChangeScheduled(
            "FeeRecipient",
            feeRecipient,
            _feeRecipient,
            pendingFeeRecipientChange.effectiveTime
        );
    }

    /**
     * @dev Apply pending fee recipient address change
     */
    function applyFeeRecipientChange() external onlyOwner {
        require(pendingFeeRecipientChange.isPending, "No pending change");
        require(
            block.timestamp >= pendingFeeRecipientChange.effectiveTime,
            "Change not ready"
        );

        address oldRecipient = feeRecipient;
        feeRecipient = pendingFeeRecipientChange.newAddress;
        pendingFeeRecipientChange.isPending = false;

        // Update default royalty
        _setDefaultRoyalty(feeRecipient, DEFAULT_ROYALTY_FEE);

        emit AdminChangeApplied("FeeRecipient", oldRecipient, feeRecipient);
        emit FeeRecipientUpdated(oldRecipient, feeRecipient);
    }

    /**
     * @dev Cancel pending fee recipient address change
     */
    function cancelFeeRecipientChange() external onlyOwner {
        require(pendingFeeRecipientChange.isPending, "No pending change");

        pendingFeeRecipientChange.isPending = false;

        emit AdminChangeCanceled("FeeRecipient", feeRecipient);
    }

    /**
     * @dev Mint NFT with signature from backend
     * @param uri Token URI
     * @param creator Creator address
     * @param royaltyPercentage Royalty percentage (in basis points)
     * @param assetType Asset type
     * @param category Category
     * @param signature Backend signature
     */
    function mintNFT(
        string memory uri,
        address creator,
        uint96 royaltyPercentage,
        AssetType assetType,
        bytes32 category,
        bytes memory signature
    ) external nonReentrant whenNotPaused returns (uint256) {
        require(royaltyPercentage <= MAX_ROYALTY_FEE, "Royalty too high");
        require(creator != address(0), "Invalid creator address");
        require(bytes(uri).length > 0, "Empty token URI");

        // Verify signature
        bytes32 messageHash = keccak256(
            abi.encodePacked(
                uri,
                creator,
                royaltyPercentage,
                uint8(assetType),
                category,
                block.chainid
            )
        );
        bytes32 signedMessageHash = messageHash.toEthSignedMessageHash();
        address recoveredSigner = signedMessageHash.recover(signature);

        require(recoveredSigner == backendSigner, "Invalid signature");

        // Mint NFT
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();

        _safeMint(creator, tokenId);
        _setTokenURI(tokenId, uri);

        // Set token royalty
        if (royaltyPercentage > 0) {
            _setTokenRoyalty(tokenId, creator, royaltyPercentage);
        }

        // Store token metadata
        _tokenMetadata[tokenId] = TokenMetadata({
            category: category,
            createdAt: block.timestamp,
            assetType: assetType
        });

        // Store creator mapping
        _tokenCreators[tokenId] = creator;
        _creatorTokens[creator].push(tokenId);

        emit NFTMinted(tokenId, creator, creator, uri, category, assetType);

        // Record in query contract if available
        if (address(queryContract) != address(0)) {
            queryContract.recordNFTData(
                address(this),
                tokenId,
                creator,
                creator,
                uri,
                royaltyPercentage,
                uint8(assetType)
            );
        }

        return tokenId;
    }

    /**
     * @dev Mint NFT directly from marketplace contract
     * @param to Recipient address
     * @param uri Token URI
     * @param creator Creator address
     * @param royaltyPercentage Royalty percentage (in basis points)
     * @param assetType Asset type
     * @param category Category
     */
    function marketplaceMint(
        address to,
        string memory uri,
        address creator,
        uint96 royaltyPercentage,
        AssetType assetType,
        bytes32 category
    ) external nonReentrant whenNotPaused returns (uint256) {
        require(msg.sender == marketplace, "Only marketplace can call");
        require(royaltyPercentage <= MAX_ROYALTY_FEE, "Royalty too high");
        require(to != address(0), "Invalid recipient address");
        require(creator != address(0), "Invalid creator address");
        require(bytes(uri).length > 0, "Empty token URI");

        // Mint NFT
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();

        _safeMint(to, tokenId);
        _setTokenURI(tokenId, uri);

        // Set token royalty
        if (royaltyPercentage > 0) {
            _setTokenRoyalty(tokenId, creator, royaltyPercentage);
        }

        // Store token metadata
        _tokenMetadata[tokenId] = TokenMetadata({
            category: category,
            createdAt: block.timestamp,
            assetType: assetType
        });

        // Store creator mapping
        _tokenCreators[tokenId] = creator;
        _creatorTokens[creator].push(tokenId);

        emit NFTMinted(tokenId, creator, to, uri, category, assetType);

        // Record in query contract if available
        if (address(queryContract) != address(0)) {
            queryContract.recordNFTData(
                address(this),
                tokenId,
                creator,
                to,
                uri,
                royaltyPercentage,
                uint8(assetType)
            );
        }

        return tokenId;
    }

    /**
     * @dev Get token creator
     * @param tokenId Token ID
     * @return Creator address
     */
    function getCreator(uint256 tokenId) external view returns (address) {
        require(_exists(tokenId), "Token does not exist");
        return _tokenCreators[tokenId];
    }

    /**
     * @dev Get token metadata
     * @param tokenId Token ID
     * @return Token metadata
     */
    function getTokenMetadata(
        uint256 tokenId
    ) external view returns (TokenMetadata memory) {
        require(_exists(tokenId), "Token does not exist");
        return _tokenMetadata[tokenId];
    }

    /**
     * @dev Get tokens by creator
     * @param creator Creator address
     * @return Array of token IDs
     */
    function getTokensByCreator(
        address creator
    ) external view returns (uint256[] memory) {
        return _creatorTokens[creator];
    }

    /**
     * @dev Get creator token count
     * @param creator Creator address
     * @return Token count
     */
    function creatorTokenCount(
        address creator
    ) external view returns (uint256) {
        return _creatorTokens[creator].length;
    }

    /**
     * @dev Check if address is creator of token
     * @param tokenId Token ID
     * @param creator Creator address to check
     * @return Whether address is creator
     */
    function isCreator(
        uint256 tokenId,
        address creator
    ) external view returns (bool) {
        return _tokenCreators[tokenId] == creator;
    }

    // Override functions for ERC721 compatibility
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId,
        uint256 batchSize
    ) internal override(ERC721, ERC721Enumerable) whenNotPaused {
        super._beforeTokenTransfer(from, to, tokenId, batchSize);
    }

    function _burn(
        uint256 tokenId
    ) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);

        // Clear royalty information
        _resetTokenRoyalty(tokenId);
    }

    function tokenURI(
        uint256 tokenId
    ) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(
        bytes4 interfaceId
    )
        public
        view
        override(ERC721, ERC721Enumerable, ERC721URIStorage, ERC2981)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
