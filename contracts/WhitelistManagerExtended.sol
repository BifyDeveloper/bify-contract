// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * @title WhitelistManagerExtended
 * @dev Enhanced whitelist manager with tiered access and time windows
 */
contract WhitelistManagerExtended is Ownable, ReentrancyGuard {
    string public whitelistName;
    uint256 public createdAt;

    enum TierLevel {
        Invalid,
        Tier1,
        Tier2,
        Tier3
    }

    struct Tier {
        bytes32 merkleRoot;
        uint256 startTime;
        uint256 endTime;
        uint256 maxMintsPerWallet;
        uint256 price;
        bool active;
    }

    mapping(uint256 => Tier) public tiers;
    uint256 public tierCount;

    mapping(address => TierLevel) public directWhitelist;

    mapping(address => mapping(uint256 => uint256)) public mintCountByTier;

    event TierCreated(
        uint256 indexed tierId,
        bytes32 merkleRoot,
        uint256 startTime,
        uint256 endTime,
        uint256 maxMintsPerWallet,
        uint256 price
    );

    event TierUpdated(
        uint256 indexed tierId,
        bytes32 merkleRoot,
        uint256 startTime,
        uint256 endTime,
        uint256 maxMintsPerWallet,
        uint256 price,
        bool active
    );

    event DirectWhitelistAdded(address indexed user, TierLevel tier);

    event DirectWhitelistBatchAdded(uint256 userCount, TierLevel tier);

    event MintTracked(
        address indexed user,
        uint256 indexed tierId,
        uint256 quantity,
        uint256 totalMinted
    );

    event NameUpdated(string newName);

    /**
     * @dev Constructor
     * @param _name Whitelist name
     */
    constructor(string memory _name) {
        whitelistName = _name;
        createdAt = block.timestamp;
    }

    /**
     * @notice Create a new whitelist tier
     * @param _merkleRoot Merkle root of addresses in this tier
     * @param _startTime Start time for this tier
     * @param _endTime End time for this tier
     * @param _maxMintsPerWallet Maximum mints per wallet for this tier
     * @param _price Price for minting in this tier
     * @return tierId ID of the created tier
     */
    function createTier(
        bytes32 _merkleRoot,
        uint256 _startTime,
        uint256 _endTime,
        uint256 _maxMintsPerWallet,
        uint256 _price
    ) external onlyOwner returns (uint256 tierId) {
        require(_startTime < _endTime, "Invalid time window");
        require(_maxMintsPerWallet > 0, "Max mints must be > 0");

        tierId = tierCount;

        tiers[tierId] = Tier({
            merkleRoot: _merkleRoot,
            startTime: _startTime,
            endTime: _endTime,
            maxMintsPerWallet: _maxMintsPerWallet,
            price: _price,
            active: true
        });

        tierCount++;

        emit TierCreated(
            tierId,
            _merkleRoot,
            _startTime,
            _endTime,
            _maxMintsPerWallet,
            _price
        );

        return tierId;
    }

    /**
     * @notice Update an existing tier
     * @param _tierId ID of the tier to update
     * @param _merkleRoot New merkle root
     * @param _startTime New start time
     * @param _endTime New end time
     * @param _maxMintsPerWallet New max mints per wallet
     * @param _price New price
     * @param _active Whether the tier is active
     */
    function updateTier(
        uint256 _tierId,
        bytes32 _merkleRoot,
        uint256 _startTime,
        uint256 _endTime,
        uint256 _maxMintsPerWallet,
        uint256 _price,
        bool _active
    ) external onlyOwner {
        require(_tierId < tierCount, "Invalid tier ID");
        require(_startTime < _endTime, "Invalid time window");
        require(_maxMintsPerWallet > 0, "Max mints must be > 0");

        Tier storage tier = tiers[_tierId];
        tier.merkleRoot = _merkleRoot;
        tier.startTime = _startTime;
        tier.endTime = _endTime;
        tier.maxMintsPerWallet = _maxMintsPerWallet;
        tier.price = _price;
        tier.active = _active;

        emit TierUpdated(
            _tierId,
            _merkleRoot,
            _startTime,
            _endTime,
            _maxMintsPerWallet,
            _price,
            _active
        );
    }

    /**
     * @notice Add an address to the direct whitelist
     * @param _user Address to add
     * @param _tier Tier level
     */
    function addToDirectWhitelist(
        address _user,
        TierLevel _tier
    ) external onlyOwner {
        require(_user != address(0), "Invalid address");
        require(_tier != TierLevel.Invalid, "Cannot add with Invalid tier");

        directWhitelist[_user] = _tier;

        emit DirectWhitelistAdded(_user, _tier);
    }

    /**
     * @notice Batch add addresses to the direct whitelist
     * @param _users Array of addresses to add
     * @param _tier Tier level for all addresses
     * @return successCount Number of successfully added addresses
     */
    function batchAddToDirectWhitelist(
        address[] calldata _users,
        TierLevel _tier
    ) external onlyOwner returns (uint256 successCount) {
        require(_tier != TierLevel.Invalid, "Cannot add with Invalid tier");

        successCount = 0;
        for (uint256 i = 0; i < _users.length; i++) {
            address user = _users[i];
            if (user != address(0)) {
                directWhitelist[user] = _tier;
                successCount++;
            }
        }

        emit DirectWhitelistBatchAdded(successCount, _tier);
        return successCount;
    }

    /**
     * @notice Check if an address is whitelisted in a specific tier using merkle proof
     * @param _user Address to check
     * @param _tierId Tier ID to check
     * @param _proof Merkle proof
     * @return isValid Whether the address is whitelisted in this tier
     */
    function isWhitelistedInTier(
        address _user,
        uint256 _tierId,
        bytes32[] calldata _proof
    ) public view returns (bool isValid) {
        require(_tierId < tierCount, "Invalid tier ID");

        Tier storage tier = tiers[_tierId];
        if (!tier.active) {
            return false;
        }

        bytes32 leaf = keccak256(abi.encodePacked(_user));
        return MerkleProof.verify(_proof, tier.merkleRoot, leaf);
    }

    /**
     * @notice Check if an address is directly whitelisted
     * @param _user Address to check
     * @return tierLevel Tier level of the address (TierLevel.Invalid if not whitelisted)
     */
    function getDirectWhitelistTier(
        address _user
    ) public view returns (TierLevel) {
        return directWhitelist[_user];
    }

    /**
     * @notice Check if a tier is currently active based on time window
     * @param _tierId Tier ID to check
     * @return isActive Whether the tier is currently active
     * @return timeRemaining Time remaining in seconds (0 if not active)
     */
    function isTierActive(
        uint256 _tierId
    ) public view returns (bool isActive, uint256 timeRemaining) {
        require(_tierId < tierCount, "Invalid tier ID");

        Tier storage tier = tiers[_tierId];
        if (!tier.active) {
            return (false, 0);
        }

        uint256 currentTime = block.timestamp;

        if (currentTime >= tier.startTime && currentTime <= tier.endTime) {
            return (true, tier.endTime - currentTime);
        }

        return (false, 0);
    }

    /**
     * @notice Get tier price and max mints per wallet
     * @param _tierId Tier ID
     * @return price Price for this tier
     * @return maxMintsPerWallet Maximum mints per wallet for this tier
     */
    function getTierInfo(
        uint256 _tierId
    ) external view returns (uint256 price, uint256 maxMintsPerWallet) {
        require(_tierId < tierCount, "Invalid tier ID");

        Tier storage tier = tiers[_tierId];
        return (tier.price, tier.maxMintsPerWallet);
    }

    /**
     * @notice Validate mint eligibility for a user in a tier
     * @param _user User address
     * @param _tierId Tier ID
     * @param _quantity Quantity to mint
     * @param _proof Merkle proof (only needed if using merkle tree validation)
     * @return canMint Whether the user can mint
     * @return price Price per token
     */
    function validateMintEligibility(
        address _user,
        uint256 _tierId,
        uint256 _quantity,
        bytes32[] calldata _proof
    ) external view returns (bool canMint, uint256 price) {
        require(_tierId < tierCount, "Invalid tier ID");

        Tier storage tier = tiers[_tierId];

        (bool isActive, ) = isTierActive(_tierId);
        if (!isActive) {
            return (false, 0);
        }

        bool isUserWhitelisted = false;

        TierLevel directTier = directWhitelist[_user];
        if (directTier != TierLevel.Invalid) {
            isUserWhitelisted = uint256(directTier) >= _tierId + 1;
        }

        if (!isUserWhitelisted) {
            isUserWhitelisted = isWhitelistedInTier(_user, _tierId, _proof);
        }

        if (!isUserWhitelisted) {
            return (false, 0);
        }

        uint256 currentMinted = mintCountByTier[_user][_tierId];
        if (currentMinted + _quantity > tier.maxMintsPerWallet) {
            return (false, 0);
        }

        return (true, tier.price);
    }

    /**
     * @notice Track a mint for a user
     * @param _user User address
     * @param _tierId Tier ID
     * @param _quantity Quantity minted
     */
    function trackMint(
        address _user,
        uint256 _tierId,
        uint256 _quantity
    ) external onlyOwner nonReentrant {
        require(_tierId < tierCount, "Invalid tier ID");
        require(_quantity > 0, "Quantity must be > 0");

        mintCountByTier[_user][_tierId] += _quantity;

        emit MintTracked(
            _user,
            _tierId,
            _quantity,
            mintCountByTier[_user][_tierId]
        );
    }

    /**
     * @notice Get all tier details
     * @return tierData Array of tier details
     */
    function getAllTiers() external view returns (Tier[] memory tierData) {
        tierData = new Tier[](tierCount);

        for (uint256 i = 0; i < tierCount; i++) {
            tierData[i] = tiers[i];
        }

        return tierData;
    }

    /**
     * @notice Update whitelist name
     * @param _newName New whitelist name
     */
    function updateName(string calldata _newName) external onlyOwner {
        whitelistName = _newName;
        emit NameUpdated(_newName);
    }

    /**
     * @notice Check if a user is whitelisted for a specific tier
     * @param _user User address to check
     * @param _tierId Tier ID to check
     * @param _merkleProof Merkle proof for verification
     * @return Whether the user is whitelisted for this tier
     */
    function isWhitelisted(
        address _user,
        uint256 _tierId,
        bytes32[] calldata _merkleProof
    ) external view returns (bool) {
        if (directWhitelist[_user] != TierLevel.Invalid) {
            uint256 userTierLevel = uint256(directWhitelist[_user]);
            return userTierLevel >= _tierId + 1;
        }

        if (_tierId < tierCount) {
            Tier storage tier = tiers[_tierId];
            if (
                tier.active &&
                block.timestamp >= tier.startTime &&
                block.timestamp <= tier.endTime
            ) {
                bytes32 leaf = keccak256(abi.encodePacked(_user, _tierId));
                return MerkleProof.verify(_merkleProof, tier.merkleRoot, leaf);
            }
        }

        return false;
    }

    /**
     * @notice Get the price for a specific tier
     * @param _tierId Tier ID to check
     * @return Price for the tier
     */
    function getTierPrice(uint256 _tierId) external view returns (uint256) {
        require(_tierId < tierCount, "Invalid tier ID");
        return tiers[_tierId].price;
    }

    /**
     * @notice Get the number of available mints for a user in a tier
     * @param _user User address to check
     * @param _tierId Tier ID to check
     * @return Number of available mints
     */
    function getAvailableMints(
        address _user,
        uint256 _tierId
    ) external view returns (uint256) {
        require(_tierId < tierCount, "Invalid tier ID");
        Tier storage tier = tiers[_tierId];
        uint256 minted = mintCountByTier[_user][_tierId];

        if (minted >= tier.maxMintsPerWallet) {
            return 0;
        }

        return tier.maxMintsPerWallet - minted;
    }

    /**
     * @notice Check if a tier is currently active
     * @param _tierId Tier ID to check
     * @return Whether the tier is active and within time window
     */
    function checkTierActive(uint256 _tierId) external view returns (bool) {
        if (_tierId >= tierCount) return false;

        Tier storage tier = tiers[_tierId];
        return
            tier.active &&
            block.timestamp >= tier.startTime &&
            block.timestamp <= tier.endTime;
    }

    /**
     * @notice Get all tier info at once
     * @param _tierId Tier ID to query
     * @return merkleRoot Merkle root for the tier
     * @return startTime Start time for the tier
     * @return endTime End time for the tier
     * @return maxMintsPerWallet Maximum mints per wallet for the tier
     * @return price Price for minting in this tier
     * @return active Whether the tier is active
     */
    function getTierInfoDetailed(
        uint256 _tierId
    )
        external
        view
        returns (
            bytes32 merkleRoot,
            uint256 startTime,
            uint256 endTime,
            uint256 maxMintsPerWallet,
            uint256 price,
            bool active
        )
    {
        require(_tierId < tierCount, "Invalid tier ID");
        Tier storage tier = tiers[_tierId];

        return (
            tier.merkleRoot,
            tier.startTime,
            tier.endTime,
            tier.maxMintsPerWallet,
            tier.price,
            tier.active
        );
    }
}
