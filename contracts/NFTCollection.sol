// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "./IWhitelistManagerExtended.sol";

contract NFTCollection is ERC721Enumerable, ERC2981, Ownable, ReentrancyGuard {
    using Strings for uint256;
    using ECDSA for bytes32;

    string public baseURI;
    uint256 public maxSupply;

    uint256 public mintStartTime;
    uint256 public mintEndTime;
    uint256 public mintPrice;
    uint256 public maxMintsPerWallet;

    bool public whitelistEnabled;
    bytes32 public whitelistMerkleRoot;
    uint256 public whitelistMintStartTime;
    uint256 public whitelistMintEndTime;
    uint256 public whitelistMintPrice;
    uint256 public whitelistMaxMintsPerWallet;

    mapping(address => uint256) public addressMintCount;
    mapping(address => uint256) public addressWhitelistMintCount;
    bool public mintingPaused;

    uint256 public nextTokenId = 1;

    enum RevealStrategy {
        STANDARD,
        BLIND_BOX,
        RANDOMIZED,
        DYNAMIC
    }
    RevealStrategy public revealStrategy;
    bool public revealed = false;
    string public notRevealedURI;
    uint256 public revealTimestamp;
    uint256 public randomSeed;
    bool public seedSet;
    address public marketplaceFeeRecipient;
    uint256 public marketplaceFee;

    mapping(uint256 => uint256) private _finalTokenIds;

    mapping(uint256 => uint256) public tokenVersion;
    mapping(uint256 => string) private _tokenURIs;

    event Minted(address indexed recipient, uint256 tokenId, uint256 price);
    event BatchMinted(
        address indexed recipient,
        uint256 startTokenId,
        uint256 endTokenId
    );
    event BaseURIUpdated(string oldURI, string newURI);
    event MintingPaused(bool isPaused);
    event WhitelistUpdated(bytes32 merkleRoot);
    event WhitelistConfigUpdated(
        uint256 startTime,
        uint256 endTime,
        uint256 price,
        uint256 maxPerWallet
    );
    event MintConfigUpdated(
        uint256 startTime,
        uint256 endTime,
        uint256 price,
        uint256 maxPerWallet
    );
    event FundsWithdrawn(address recipient, uint256 amount);
    event RevealStatusChanged(bool isRevealed);
    event RevealStrategySet(RevealStrategy strategy);
    event RevealTimeSet(uint256 revealTime);
    event TokenEvolved(uint256 indexed tokenId, uint256 version);
    event RandomSeedSet(uint256 seed);

    /**
     * @dev Constructor
     */
    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _maxSupply,
        uint96 _royaltyPercentage,
        string memory _baseURI,
        uint256 _mintStartTime,
        uint256 _mintEndTime,
        uint256 _mintPrice,
        uint256 _maxMintsPerWallet,
        address _creator,
        RevealStrategy _revealStrategy
    ) ERC721(_name, _symbol) {
        maxSupply = _maxSupply;
        baseURI = _baseURI;
        mintStartTime = _mintStartTime;
        mintEndTime = _mintEndTime;
        mintPrice = _mintPrice;
        maxMintsPerWallet = _maxMintsPerWallet;
        revealStrategy = _revealStrategy;
        notRevealedURI = "ipfs://QmNotRevealed";
        _setDefaultRoyalty(_creator, _royaltyPercentage);

        if (_creator != msg.sender) {
            transferOwnership(_creator);
        }

        marketplaceFee = 250;
        marketplaceFeeRecipient = _creator;

        if (
            _revealStrategy == RevealStrategy.STANDARD &&
            _revealStrategy != RevealStrategy.DYNAMIC
        ) {
            revealed = true;
        }

        emit RevealStrategySet(_revealStrategy);
    }

    /**
     * @notice Public mint function
     * @param _quantity Number of NFTs to mint
     */
    function mint(uint256 _quantity) external payable nonReentrant {
        require(!mintingPaused, "Minting is paused");
        require(block.timestamp >= mintStartTime, "Mint not started");
        require(block.timestamp <= mintEndTime, "Mint ended");
        require(nextTokenId + _quantity - 1 <= maxSupply, "Exceeds max supply");
        require(
            addressMintCount[msg.sender] + _quantity <= maxMintsPerWallet,
            "Exceeds wallet limit"
        );
        require(msg.value >= mintPrice * _quantity, "Insufficient payment");

        addressMintCount[msg.sender] += _quantity;

        _mintBatch(msg.sender, _quantity);
    }

    /**
     * @notice Whitelist mint function
     * @param _quantity Number of NFTs to mint
     * @param _merkleProof Merkle proof to verify caller is whitelisted
     * @param _tierId Tier ID for tiered whitelists (used for verification)
     */
    function whitelistMint(
        uint256 _quantity,
        bytes32[] calldata _merkleProof,
        uint256 _tierId
    ) external payable nonReentrant {
        require(!mintingPaused, "Minting is paused");
        require(whitelistEnabled, "Whitelist not enabled");
        require(
            block.timestamp >= whitelistMintStartTime,
            "Whitelist mint not started"
        );
        require(
            block.timestamp <= whitelistMintEndTime,
            "Whitelist mint ended"
        );
        require(nextTokenId + _quantity - 1 <= maxSupply, "Exceeds max supply");

        address whitelistAddr = address(uint160(uint256(whitelistMerkleRoot)));
        bool isExternalWhitelist = whitelistAddr != address(0) &&
            whitelistAddr.code.length > 0;

        if (isExternalWhitelist) {
            IWhitelistManagerExtended whitelistManager = IWhitelistManagerExtended(
                    whitelistAddr
                );

            require(
                whitelistManager.isWhitelisted(
                    msg.sender,
                    _tierId,
                    _merkleProof
                ),
                "Not whitelisted for tier"
            );

            uint256 availableMints = whitelistManager.getAvailableMints(
                msg.sender,
                _tierId
            );
            require(availableMints >= _quantity, "Exceeds tier mint limit");

            uint256 tierPrice = whitelistManager.getTierPrice(_tierId);
            require(msg.value >= tierPrice * _quantity, "Insufficient payment");

            _mintBatch(msg.sender, _quantity);

            whitelistManager.trackMint(msg.sender, _tierId, _quantity);
        } else {
            require(
                addressWhitelistMintCount[msg.sender] + _quantity <=
                    whitelistMaxMintsPerWallet,
                "Exceeds whitelist limit"
            );
            require(
                msg.value >= whitelistMintPrice * _quantity,
                "Insufficient payment"
            );

            bytes32 leaf;
            if (_tierId > 0) {
                leaf = keccak256(abi.encodePacked(msg.sender, _tierId));
            } else {
                leaf = keccak256(abi.encodePacked(msg.sender));
            }

            require(
                MerkleProof.verify(_merkleProof, whitelistMerkleRoot, leaf),
                "Invalid proof"
            );

            addressWhitelistMintCount[msg.sender] += _quantity;
            _mintBatch(msg.sender, _quantity);
        }
    }

    /**
     * @notice Owner mint function (for team allocations, giveaways, etc.)
     * @param _recipient Recipient address
     * @param _quantity Number of NFTs to mint
     */
    function ownerMint(
        address _recipient,
        uint256 _quantity
    ) external onlyOwner nonReentrant {
        require(nextTokenId + _quantity - 1 <= maxSupply, "Exceeds max supply");

        _mintBatch(_recipient, _quantity);
    }

    /**
     * @notice Internal batch minting function
     * @param _recipient Recipient address
     * @param _quantity Number of NFTs to mint
     */
    function _mintBatch(address _recipient, uint256 _quantity) internal {
        uint256 startTokenId = nextTokenId;

        for (uint256 i = 0; i < _quantity; i++) {
            _safeMint(_recipient, nextTokenId);
            nextTokenId++;
        }

        emit BatchMinted(_recipient, startTokenId, nextTokenId - 1);
    }

    /**
     * @notice Sets up whitelist configuration
     * @param _merkleRoot Merkle root of whitelist addresses
     * @param _startTime Start time for whitelist mint
     * @param _endTime End time for whitelist mint
     * @param _price Price per NFT during whitelist mint
     * @param _maxPerWallet Maximum mints per wallet during whitelist
     */
    function setWhitelistConfig(
        bytes32 _merkleRoot,
        uint256 _startTime,
        uint256 _endTime,
        uint256 _price,
        uint256 _maxPerWallet
    ) external onlyOwner {
        require(_startTime < _endTime, "Invalid time window");

        whitelistMerkleRoot = _merkleRoot;
        whitelistMintStartTime = _startTime;
        whitelistMintEndTime = _endTime;
        whitelistMintPrice = _price;
        whitelistMaxMintsPerWallet = _maxPerWallet;
        whitelistEnabled = true;

        emit WhitelistUpdated(_merkleRoot);
        emit WhitelistConfigUpdated(
            _startTime,
            _endTime,
            _price,
            _maxPerWallet
        );
    }

    /**
     * @notice Sets up external whitelist manager
     * @param _whitelistManager Address of WhitelistManagerExtended contract
     * @param _startTime Start time for whitelist mint
     * @param _endTime End time for whitelist mint
     */
    function setExternalWhitelist(
        address _whitelistManager,
        uint256 _startTime,
        uint256 _endTime
    ) external onlyOwner {
        require(_whitelistManager != address(0), "Invalid manager address");
        require(_whitelistManager.code.length > 0, "Not a contract");
        require(_startTime < _endTime, "Invalid time window");

        whitelistMerkleRoot = bytes32(uint256(uint160(_whitelistManager)));
        whitelistMintStartTime = _startTime;
        whitelistMintEndTime = _endTime;
        whitelistEnabled = true;

        emit WhitelistUpdated(bytes32(uint256(uint160(_whitelistManager))));
        emit WhitelistConfigUpdated(_startTime, _endTime, 0, 0);
    }

    /**
     * @notice Updates public mint configuration
     * @param _startTime Start time for public mint
     * @param _endTime End time for public mint
     * @param _price Price per NFT during public mint
     * @param _maxPerWallet Maximum mints per wallet during public mint
     */
    function updateMintConfig(
        uint256 _startTime,
        uint256 _endTime,
        uint256 _price,
        uint256 _maxPerWallet
    ) external onlyOwner {
        require(_startTime < _endTime, "Invalid time window");

        mintStartTime = _startTime;
        mintEndTime = _endTime;
        mintPrice = _price;
        maxMintsPerWallet = _maxPerWallet;

        emit MintConfigUpdated(_startTime, _endTime, _price, _maxPerWallet);
    }

    /**
     * @notice Updates the base URI for token metadata
     * @param _newBaseURI New base URI
     */
    function setBaseURI(string memory _newBaseURI) external onlyOwner {
        string memory oldURI = baseURI;
        baseURI = _newBaseURI;
        emit BaseURIUpdated(oldURI, _newBaseURI);
    }

    /**
     * @notice Set the URI for non-revealed tokens
     * @param _notRevealedURI New URI for unrevealed tokens
     */
    function setNotRevealedURI(
        string memory _notRevealedURI
    ) external onlyOwner {
        notRevealedURI = _notRevealedURI;
    }

    /**
     * @notice Set reveal strategy
     * @param _strategy New reveal strategy
     */
    function setRevealStrategy(RevealStrategy _strategy) external onlyOwner {
        if (revealStrategy == RevealStrategy.RANDOMIZED && seedSet) {
            require(
                _strategy == RevealStrategy.RANDOMIZED,
                "Can't change from RANDOMIZED after seed is set"
            );
        }

        revealStrategy = _strategy;

        if (_strategy == RevealStrategy.STANDARD) {
            revealed = true;
            emit RevealStatusChanged(true);
        }

        emit RevealStrategySet(_strategy);
    }

    /**
     * @notice Set delayed reveal time
     * @param _revealTimestamp Timestamp when collection will be revealed
     */
    function setRevealTime(uint256 _revealTimestamp) external onlyOwner {
        require(
            revealStrategy == RevealStrategy.STANDARD,
            "Only for STANDARD reveal strategy"
        );
        require(
            _revealTimestamp > block.timestamp,
            "Reveal time must be in future"
        );

        revealTimestamp = _revealTimestamp;
        revealed = false;

        emit RevealTimeSet(_revealTimestamp);
        emit RevealStatusChanged(false);
    }

    /**
     * @notice Manually trigger reveal
     */
    function reveal() external onlyOwner {
        require(!revealed, "Already revealed");

        revealed = true;
        emit RevealStatusChanged(true);
    }

    /**
     * @notice Set random seed for RANDOMIZED reveal strategy
     * @param _seed Random seed for token shuffling
     */
    function setRandomSeed(uint256 _seed) external onlyOwner {
        require(
            revealStrategy == RevealStrategy.RANDOMIZED,
            "Not using RANDOMIZED strategy"
        );
        require(!seedSet, "Seed already set");

        randomSeed = _seed;
        seedSet = true;
        revealed = true;

        for (uint256 i = 1; i <= maxSupply; i++) {
            uint256 pseudoRandomNumber = uint256(
                keccak256(abi.encodePacked(i, _seed))
            );
            _finalTokenIds[i] = (pseudoRandomNumber % maxSupply) + 1;
        }

        emit RandomSeedSet(_seed);
        emit RevealStatusChanged(true);
    }

    /**
     * @notice Evolve token's metadata (for DYNAMIC strategy)
     * @param _tokenId Token ID to evolve
     * @param _newTokenURI New token URI
     */
    function evolveToken(
        uint256 _tokenId,
        string memory _newTokenURI
    ) external onlyOwner {
        require(
            revealStrategy == RevealStrategy.DYNAMIC,
            "Not using DYNAMIC strategy"
        );
        require(_exists(_tokenId), "Token does not exist");

        _tokenURIs[_tokenId] = _newTokenURI;
        tokenVersion[_tokenId]++;

        emit TokenEvolved(_tokenId, tokenVersion[_tokenId]);
    }

    /**
     * @notice Toggles pausing of minting
     * @param _paused Pause state to set
     */
    function setPaused(bool _paused) external onlyOwner {
        mintingPaused = _paused;
        emit MintingPaused(_paused);
    }

    /**
     * @notice Updates default royalty information
     * @param _receiver Royalty receiver address
     * @param _feeNumerator Royalty percentage (in basis points)
     */
    function setDefaultRoyalty(
        address _receiver,
        uint96 _feeNumerator
    ) external onlyOwner {
        require(_feeNumerator <= 1000, "Royalty cannot exceed 10%");
        _setDefaultRoyalty(_receiver, _feeNumerator);
    }

    /**
     * @notice Set marketplace fee recipient
     * @param _feeRecipient Address to receive marketplace fees
     */
    function setMarketplaceFeeRecipient(
        address _feeRecipient
    ) external onlyOwner {
        require(_feeRecipient != address(0), "Invalid fee recipient");
        marketplaceFeeRecipient = _feeRecipient;
    }

    /**
     * @notice Set marketplace fee percentage (in basis points)
     * @param _fee Fee percentage (250 = 2.5%)
     */
    function setMarketplaceFee(uint256 _fee) external onlyOwner {
        require(_fee <= 1000, "Fee cannot exceed 10%");
        marketplaceFee = _fee;
    }

    /**
     * @notice Withdraws contract balance to owner
     */
    function withdraw() external onlyOwner nonReentrant {
        uint256 balance = address(this).balance;
        require(balance > 0, "No balance to withdraw");

        uint256 marketplacePortion = (balance * marketplaceFee) / 10000;
        uint256 ownerPortion = balance - marketplacePortion;

        if (marketplacePortion > 0) {
            (bool marketplaceSuccess, ) = payable(marketplaceFeeRecipient).call{
                value: marketplacePortion
            }("");
            require(marketplaceSuccess, "Marketplace fee transfer failed");
        }

        (bool success, ) = owner().call{value: ownerPortion}("");
        require(success, "Withdrawal failed");

        emit FundsWithdrawn(owner(), balance);
    }

    /**
     * @notice Returns token URI for a given token ID
     * @param tokenId Token ID to query
     * @return Token URI
     */
    function tokenURI(
        uint256 tokenId
    ) public view override returns (string memory) {
        _requireMinted(tokenId);

        bool revealStatus = revealed;
        if (revealStrategy == RevealStrategy.STANDARD && revealTimestamp > 0) {
            revealStatus = revealStatus || (block.timestamp >= revealTimestamp);
        }

        if (!revealStatus) {
            return notRevealedURI;
        }

        if (revealStrategy == RevealStrategy.RANDOMIZED && seedSet) {
            uint256 finalId = _finalTokenIds[tokenId];
            return
                string(abi.encodePacked(baseURI, finalId.toString(), ".json"));
        } else if (revealStrategy == RevealStrategy.DYNAMIC) {
            string memory customURI = _tokenURIs[tokenId];
            if (bytes(customURI).length > 0) {
                return customURI;
            }
        }

        return string(abi.encodePacked(baseURI, tokenId.toString(), ".json"));
    }

    /**
     * @notice Checks if interface is supported (ERC165)
     */
    function supportsInterface(
        bytes4 interfaceId
    ) public view override(ERC721Enumerable, ERC2981) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    /**
     * @notice Returns all token IDs owned by an address
     * @param _owner Address to query
     * @return Array of token IDs
     */
    function tokensOfOwner(
        address _owner
    ) external view returns (uint256[] memory) {
        uint256 tokenCount = balanceOf(_owner);
        uint256[] memory tokenIds = new uint256[](tokenCount);

        for (uint256 i = 0; i < tokenCount; i++) {
            tokenIds[i] = tokenOfOwnerByIndex(_owner, i);
        }

        return tokenIds;
    }

    /**
     * @notice Check if collection is revealed (considering auto-reveal)
     * @return True if revealed, false otherwise
     */
    function isRevealed() external view returns (bool) {
        if (revealed) return true;

        if (revealStrategy == RevealStrategy.STANDARD && revealTimestamp > 0) {
            return block.timestamp >= revealTimestamp;
        }

        return false;
    }

    /**
     * @dev Receive function to accept ETH
     */
    receive() external payable {}
}
