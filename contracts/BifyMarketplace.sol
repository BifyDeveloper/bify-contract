// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/interfaces/IERC2981.sol";
import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "./MarketplaceQuery.sol";
import "./BifyTokenPayment.sol";
import "./libraries/MarketplaceValidation.sol";

/**
 * @title BifyMarketplace
 * @dev Implements a marketplace for BifyNFTs with auction functionality
 * Enhanced with batch operations, pausability, improved query integration,
 * and support for BIFY token payments.
 */
contract BifyMarketplace is Ownable, ReentrancyGuard, Pausable {
    using SafeMath for uint256;
    using MarketplaceValidation for *;

    enum AuctionStatus {
        Active,
        Ended,
        Canceled
    }
    enum AssetType {
        NFT,
        RWA
    }

    enum PaymentMethod {
        ETH,
        BIFY
    }
    struct Auction {
        address seller;
        address nftContract;
        uint256 tokenId;
        uint256 reservePrice;
        uint256 buyNowPrice;
        uint256 startTime;
        uint256 endTime;
        address highestBidder;
        uint256 highestBid;
        bool isSettled;
        AuctionStatus status;
        uint256 royaltyPercentage;
        AssetType assetType;
        bytes32 category;
        PaymentMethod paymentMethod;
    }

    struct BidInfo {
        address bidder;
        uint256 amount;
        uint256 timestamp;
        PaymentMethod paymentMethod;
    }

    struct FixedPriceListing {
        address seller;
        address nftContract;
        uint256 tokenId;
        uint256 price;
        bool isActive;
        AssetType assetType;
        uint256 royaltyPercentage;
        bytes32 category;
        PaymentMethod paymentMethod;
    }
    struct PendingParameterChange {
        uint256 platformFeePercentage;
        uint256 bidDepositPercentage;
        uint256 minRoyaltyPercentage;
        uint256 maxRoyaltyPercentage;
        address platformFeeRecipient;
        uint256 effectiveTime;
    }

    address public platformFeeRecipient;
    uint256 public standardPlatformFeePercentage = 5; // 0.5% for regular marketplace NFTs
    uint256 public launchpadPlatformFeePercentage = 50; // 5% for launchpad-created NFTs
    uint256 public platformFeePercentage = 5; // Deprecated - keeping for backward compatibility
    uint256 public bidDepositPercentage = 50;
    uint256 public constant ANTI_SNIPE_TIME = 10 minutes;
    uint256 public constant MIN_BID_INCREMENT_PERCENTAGE = 25;
    uint256 public minRoyaltyPercentage = 50;
    uint256 public maxRoyaltyPercentage = 100;
    uint256 public constant BASIS_POINTS = 1000;
    uint256 public constant PARAMETER_CHANGE_DELAY = 2 days;

    uint256 public auctionIdCounter;
    uint256 public listingIdCounter;

    MarketplaceQuery public queryContract;

    BifyTokenPayment public tokenPaymentProcessor;
    IERC20 public bifyToken;

    PendingParameterChange public pendingChange;
    bool public hasPendingChange;

    mapping(uint256 => Auction) public auctions;
    mapping(uint256 => FixedPriceListing) public fixedPriceListings;
    mapping(address => mapping(uint256 => address)) public tokenCreators;
    mapping(address => uint256) public pendingWithdrawals;

    // Launchpad collection registry for fee differentiation
    mapping(address => bool) public launchpadCollections;

    // Add authorized registrars mapping for launchpad integration
    mapping(address => bool) public authorizedRegistrars;

    mapping(uint256 => BidInfo[]) public bidHistory;
    mapping(uint256 => mapping(address => uint256)) public maxBids;

    event AuctionCreated(
        uint256 indexed auctionId,
        address indexed seller,
        address indexed nftContract,
        uint256 tokenId,
        uint256 reservePrice,
        uint256 buyNowPrice,
        uint256 startTime,
        uint256 endTime,
        AssetType assetType,
        uint256 royaltyPercentage,
        bytes32 category,
        PaymentMethod paymentMethod
    );

    event FixedPriceListingCreated(
        uint256 indexed listingId,
        address indexed seller,
        address indexed nftContract,
        uint256 tokenId,
        uint256 price,
        AssetType assetType,
        uint256 royaltyPercentage,
        bytes32 category,
        PaymentMethod paymentMethod
    );

    event FixedPricePurchase(
        uint256 indexed listingId,
        address indexed buyer,
        uint256 price,
        PaymentMethod paymentMethod
    );

    event BidPlaced(
        uint256 indexed auctionId,
        address indexed bidder,
        uint256 bidAmount,
        bool isExtended,
        PaymentMethod paymentMethod
    );

    event AuctionExtended(uint256 indexed auctionId, uint256 newEndTime);

    event AuctionSettled(
        uint256 indexed auctionId,
        address indexed winner,
        uint256 winningBid,
        PaymentMethod paymentMethod
    );

    event AuctionCanceled(uint256 indexed auctionId);

    event BuyNowPurchase(
        uint256 indexed auctionId,
        address indexed buyer,
        uint256 price,
        PaymentMethod paymentMethod
    );

    event RoyaltyPaid(address indexed creator, uint256 amount);

    event WithdrawalMade(address indexed user, uint256 amount);

    event MaxBidSet(
        uint256 indexed auctionId,
        address indexed bidder,
        uint256 maxBidAmount,
        PaymentMethod paymentMethod
    );

    event FeesUpdated(
        uint256 platformFeePercentage,
        uint256 bidDepositPercentage
    );

    event ParameterChangeScheduled(
        uint256 platformFeePercentage,
        uint256 bidDepositPercentage,
        uint256 minRoyaltyPercentage,
        uint256 maxRoyaltyPercentage,
        address platformFeeRecipient,
        uint256 effectiveTime
    );

    event ParameterChangeApplied(
        uint256 platformFeePercentage,
        uint256 bidDepositPercentage,
        uint256 minRoyaltyPercentage,
        uint256 maxRoyaltyPercentage,
        address platformFeeRecipient
    );

    event ParameterChangeCanceled();

    event TokenPaymentProcessorSet(address indexed processor);
    event BifyTokenSet(address indexed tokenAddress);

    event FixedPriceListingEdited(
        uint256 indexed listingId,
        uint256 oldPrice,
        uint256 newPrice
    );

    event AuctionEdited(
        uint256 indexed auctionId,
        uint256 oldReservePrice,
        uint256 newReservePrice,
        uint256 oldBuyNowPrice,
        uint256 newBuyNowPrice
    );

    event PlatformFeePercentageUpdated(
        uint256 oldPercentage,
        uint256 newPercentage
    );
    event PlatformFeeRecipientUpdated(
        address oldRecipient,
        address newRecipient
    );
    event StandardFeePercentageUpdated(
        uint256 oldPercentage,
        uint256 newPercentage
    );
    event LaunchpadFeePercentageUpdated(
        uint256 oldPercentage,
        uint256 newPercentage
    );
    event LaunchpadCollectionRegistered(address indexed collection);
    event LaunchpadCollectionUnregistered(address indexed collection);
    event AuthorizedRegistrarUpdated(
        address indexed registrar,
        bool authorized
    );

    /**
     * @dev Constructor
     * @param _feeRecipient Address to receive platform fees
     */
    constructor(address _feeRecipient) {
        require(_feeRecipient != address(0), "Invalid fee recipient");
        platformFeeRecipient = _feeRecipient;
    }

    /**
     * @dev Sets the token payment processor contract
     * @param _tokenPaymentProcessor Address of the BifyTokenPayment contract
     */
    function setTokenPaymentProcessor(
        address _tokenPaymentProcessor
    ) external onlyOwner {
        require(
            _tokenPaymentProcessor != address(0),
            "Invalid token payment processor"
        );
        tokenPaymentProcessor = BifyTokenPayment(_tokenPaymentProcessor);
        emit TokenPaymentProcessorSet(_tokenPaymentProcessor);
    }

    /**
     * @dev Sets the BIFY token address
     * @param _bifyToken Address of the BIFY token contract
     */
    function setBifyToken(address _bifyToken) external onlyOwner {
        require(_bifyToken != address(0), "Invalid token address");
        bifyToken = IERC20(_bifyToken);
        emit BifyTokenSet(_bifyToken);
    }

    /**
     * @dev Create a fixed price listing with BIFY token as payment
     * @param nftContract Address of the NFT contract
     * @param tokenId Token ID to list
     * @param price Price in BIFY tokens
     * @param assetType Asset type (NFT or RWA)
     * @param royaltyPercentage Royalty percentage (between min and max)
     * @param category Category for filtering
     * @return listingId The ID of the created listing
     */
    function createFixedPriceListingWithToken(
        address nftContract,
        uint256 tokenId,
        uint256 price,
        AssetType assetType,
        uint256 royaltyPercentage,
        bytes32 category
    ) external whenNotPaused nonReentrant returns (uint256 listingId) {
        require(
            address(tokenPaymentProcessor) != address(0),
            "Token payment not configured"
        );
        require(address(bifyToken) != address(0), "BIFY token not configured");

        require(nftContract != address(0), "Invalid NFT contract");
        require(price > 0, "Price must be > 0");
        uint256 collectionMinRoyalty = getMinimumRoyaltyForCollection(
            nftContract
        );
        require(
            royaltyPercentage >= collectionMinRoyalty &&
                royaltyPercentage <= maxRoyaltyPercentage,
            "Invalid royalty percentage"
        );

        IERC721(nftContract).transferFrom(msg.sender, address(this), tokenId);

        if (tokenCreators[nftContract][tokenId] == address(0)) {
            tokenCreators[nftContract][tokenId] = msg.sender;
        }
        listingId = listingIdCounter++;

        fixedPriceListings[listingId] = FixedPriceListing({
            seller: msg.sender,
            nftContract: nftContract,
            tokenId: tokenId,
            price: price,
            isActive: true,
            assetType: assetType,
            royaltyPercentage: royaltyPercentage,
            category: category,
            paymentMethod: PaymentMethod.BIFY
        });

        if (address(queryContract) != address(0)) {
            queryContract.recordListing(
                listingId,
                msg.sender,
                nftContract,
                tokenId,
                price,
                uint8(assetType),
                royaltyPercentage,
                category
            );
        }

        emit FixedPriceListingCreated(
            listingId,
            msg.sender,
            nftContract,
            tokenId,
            price,
            assetType,
            royaltyPercentage,
            category,
            PaymentMethod.BIFY
        );

        return listingId;
    }

    /**
     * @dev Buy a fixed price listing using BIFY token
     * @param listingId ID of the listing to purchase
     */
    function buyFixedPriceWithToken(
        uint256 listingId
    ) external nonReentrant whenNotPaused {
        require(
            address(tokenPaymentProcessor) != address(0),
            "Token payment not configured"
        );
        require(address(bifyToken) != address(0), "BIFY token not configured");

        FixedPriceListing storage listing = fixedPriceListings[listingId];

        require(listing.isActive, "Listing not active");
        require(
            listing.paymentMethod == PaymentMethod.BIFY,
            "Not a token payment listing"
        );

        require(msg.sender != listing.seller, "Seller cannot buy");

        listing.isActive = false;

        bytes32 paymentId = keccak256(
            abi.encodePacked(listingId, "fixed", block.timestamp)
        );

        bool paymentSuccess = tokenPaymentProcessor.processPayment(
            msg.sender,
            listing.seller,
            listing.price,
            paymentId
        );

        require(paymentSuccess, "Token payment processing failed");

        IERC721(listing.nftContract).transferFrom(
            address(this),
            msg.sender,
            listing.tokenId
        );

        if (address(queryContract) != address(0)) {
            queryContract.recordListingPurchased(listingId, msg.sender);
        }

        emit FixedPricePurchase(
            listingId,
            msg.sender,
            listing.price,
            PaymentMethod.BIFY
        );
    }

    /**
     * @dev Create an auction with BIFY token as payment method
     */
    function createAuctionWithToken(
        address nftContract,
        uint256 tokenId,
        uint256 reservePrice,
        uint256 buyNowPrice,
        uint256 startTime,
        uint256 duration,
        AssetType assetType,
        uint256 royaltyPercentage,
        bytes32 category
    ) external whenNotPaused nonReentrant returns (uint256 auctionId) {
        require(
            address(tokenPaymentProcessor) != address(0),
            "Token payment not configured"
        );
        require(address(bifyToken) != address(0), "BIFY token not configured");

        require(nftContract != address(0), "Invalid NFT contract");
        require(duration >= 1 hours, "Min duration 1 hour");
        require(duration <= 30 days, "Max duration 30 days");
        require(
            reservePrice > 0 || buyNowPrice > 0,
            "Reserve or buyNow must be > 0"
        );
        require(
            buyNowPrice == 0 || buyNowPrice >= reservePrice,
            "BuyNow must exceed reserve"
        );
        uint256 collectionMinRoyalty = getMinimumRoyaltyForCollection(
            nftContract
        );
        require(
            royaltyPercentage >= collectionMinRoyalty &&
                royaltyPercentage <= maxRoyaltyPercentage,
            "Invalid royalty percentage"
        );

        if (startTime == 0) {
            startTime = block.timestamp;
        } else {
            require(startTime >= block.timestamp, "Start time in past");
        }

        uint256 endTime = startTime + duration;

        IERC721(nftContract).transferFrom(msg.sender, address(this), tokenId);

        if (tokenCreators[nftContract][tokenId] == address(0)) {
            tokenCreators[nftContract][tokenId] = msg.sender;
        }

        auctionId = auctionIdCounter++;

        auctions[auctionId] = Auction({
            seller: msg.sender,
            nftContract: nftContract,
            tokenId: tokenId,
            reservePrice: reservePrice,
            buyNowPrice: buyNowPrice,
            startTime: startTime,
            endTime: endTime,
            highestBidder: address(0),
            highestBid: 0,
            isSettled: false,
            status: AuctionStatus.Active,
            royaltyPercentage: royaltyPercentage,
            assetType: assetType,
            category: category,
            paymentMethod: PaymentMethod.BIFY
        });

        if (address(queryContract) != address(0)) {
            queryContract.recordAuction(
                auctionId,
                msg.sender,
                nftContract,
                tokenId,
                reservePrice,
                buyNowPrice,
                startTime,
                endTime,
                royaltyPercentage,
                uint8(assetType),
                category
            );
        }

        emit AuctionCreated(
            auctionId,
            msg.sender,
            nftContract,
            tokenId,
            reservePrice,
            buyNowPrice,
            startTime,
            endTime,
            assetType,
            royaltyPercentage,
            category,
            PaymentMethod.BIFY
        );

        return auctionId;
    }

    /**
     * @dev Place a bid with BIFY tokens
     */
    function placeBidWithToken(
        uint256 auctionId,
        uint256 bidAmount
    ) external nonReentrant whenNotPaused {
        require(
            address(tokenPaymentProcessor) != address(0),
            "Token payment not configured"
        );
        require(address(bifyToken) != address(0), "BIFY token not configured");

        Auction storage auction = auctions[auctionId];

        require(auction.status == AuctionStatus.Active, "Auction not active");
        require(block.timestamp >= auction.startTime, "Auction not started");
        require(block.timestamp < auction.endTime, "Auction ended");
        require(msg.sender != auction.seller, "Seller cannot bid");
        require(
            auction.paymentMethod == PaymentMethod.BIFY,
            "Not a token payment auction"
        );

        if (auction.highestBid > 0) {
            uint256 minIncrement = (auction.highestBid *
                MIN_BID_INCREMENT_PERCENTAGE) / BASIS_POINTS;
            uint256 minBidAmount = auction.highestBid + minIncrement;
            require(bidAmount >= minBidAmount, "Bid increment too small");
        } else {
            require(bidAmount >= auction.reservePrice, "Below reserve price");
        }

        bool isBuyNow = false;
        if (auction.buyNowPrice > 0 && bidAmount >= auction.buyNowPrice) {
            bidAmount = auction.buyNowPrice;
            isBuyNow = true;
        }

        if (auction.highestBidder != address(0)) {
            require(
                bifyToken.transfer(auction.highestBidder, auction.highestBid),
                "Token refund to previous bidder failed"
            );
        }

        require(
            bifyToken.transferFrom(msg.sender, address(this), bidAmount),
            "Token transfer failed"
        );

        auction.highestBidder = msg.sender;
        auction.highestBid = bidAmount;

        bidHistory[auctionId].push(
            BidInfo({
                bidder: msg.sender,
                amount: bidAmount,
                timestamp: block.timestamp,
                paymentMethod: PaymentMethod.BIFY
            })
        );

        bool extended = false;
        if (!isBuyNow && auction.endTime - block.timestamp < ANTI_SNIPE_TIME) {
            auction.endTime = block.timestamp + ANTI_SNIPE_TIME;
            extended = true;
            emit AuctionExtended(auctionId, auction.endTime);
        }

        if (address(queryContract) != address(0)) {
            queryContract.recordBid(auctionId, msg.sender, bidAmount);
        }

        emit BidPlaced(
            auctionId,
            msg.sender,
            bidAmount,
            extended,
            PaymentMethod.BIFY
        );

        if (isBuyNow) {
            emit BuyNowPurchase(
                auctionId,
                msg.sender,
                auction.buyNowPrice,
                PaymentMethod.BIFY
            );
            _settleTokenAuction(auctionId);
        }
    }

    /**
     * @dev Buy an auction immediately with BIFY tokens
     */
    function buyNowWithToken(
        uint256 auctionId
    ) external nonReentrant whenNotPaused {
        require(
            address(tokenPaymentProcessor) != address(0),
            "Token payment not configured"
        );
        require(address(bifyToken) != address(0), "BIFY token not configured");

        Auction storage auction = auctions[auctionId];

        require(auction.status == AuctionStatus.Active, "Auction not active");
        require(block.timestamp >= auction.startTime, "Auction not started");
        require(block.timestamp < auction.endTime, "Auction ended");
        require(auction.buyNowPrice > 0, "No buy now price");
        require(
            auction.paymentMethod == PaymentMethod.BIFY,
            "Not a token payment auction"
        );

        if (auction.highestBidder != address(0)) {
            require(
                bifyToken.transfer(auction.highestBidder, auction.highestBid),
                "Token refund to previous bidder failed"
            );
        }

        require(
            bifyToken.transferFrom(
                msg.sender,
                address(this),
                auction.buyNowPrice
            ),
            "Token transfer failed"
        );

        auction.highestBidder = msg.sender;
        auction.highestBid = auction.buyNowPrice;

        bidHistory[auctionId].push(
            BidInfo({
                bidder: msg.sender,
                amount: auction.buyNowPrice,
                timestamp: block.timestamp,
                paymentMethod: PaymentMethod.BIFY
            })
        );

        if (address(queryContract) != address(0)) {
            queryContract.recordBid(auctionId, msg.sender, auction.buyNowPrice);
        }

        _settleTokenAuction(auctionId);

        emit BuyNowPurchase(
            auctionId,
            msg.sender,
            auction.buyNowPrice,
            PaymentMethod.BIFY
        );
    }

    /**
     * @dev Settle an auction that uses BIFY tokens
     */
    function settleTokenAuction(
        uint256 auctionId
    ) external nonReentrant whenNotPaused {
        Auction storage auction = auctions[auctionId];

        require(
            auction.status == AuctionStatus.Active,
            "Auction not in active state"
        );
        require(block.timestamp > auction.endTime, "Auction not ended");
        require(!auction.isSettled, "Auction already settled");
        require(
            auction.paymentMethod == PaymentMethod.BIFY,
            "Not a token payment auction"
        );

        _settleTokenAuction(auctionId);
    }

    /**
     * @dev Internal function to settle a token-based auction
     */
    function _settleTokenAuction(uint256 auctionId) internal {
        Auction storage auction = auctions[auctionId];

        auction.status = AuctionStatus.Ended;
        auction.isSettled = true;

        address winningBidder = auction.highestBidder;

        if (winningBidder != address(0)) {
            _distributeTokenPayment(auction);

            IERC721(auction.nftContract).transferFrom(
                address(this),
                winningBidder,
                auction.tokenId
            );

            if (address(queryContract) != address(0)) {
                queryContract.recordAuctionSettled(auctionId, winningBidder);
            }

            emit AuctionSettled(
                auctionId,
                winningBidder,
                auction.highestBid,
                PaymentMethod.BIFY
            );
        } else {
            IERC721(auction.nftContract).transferFrom(
                address(this),
                auction.seller,
                auction.tokenId
            );

            if (address(queryContract) != address(0)) {
                queryContract.recordAuctionCanceled(auctionId);
            }

            emit AuctionCanceled(auctionId);
        }
    }

    /**
     * @dev Internal function to distribute BIFY token payments after auction ends
     */
    function _distributeTokenPayment(Auction storage auction) internal {
        uint256 saleAmount = auction.highestBid;
        address creator = tokenCreators[auction.nftContract][auction.tokenId];

        // Determine fee percentage based on whether NFT is from launchpad
        uint256 feePercentage = launchpadCollections[auction.nftContract]
            ? launchpadPlatformFeePercentage
            : standardPlatformFeePercentage;

        uint256 platformFee = saleAmount.mul(feePercentage).div(BASIS_POINTS);
        uint256 royaltyAmount = 0;

        if (creator != address(0) && creator != auction.seller) {
            royaltyAmount = saleAmount.mul(auction.royaltyPercentage).div(
                BASIS_POINTS
            );
        }

        if (platformFee > 0) {
            require(
                bifyToken.transfer(platformFeeRecipient, platformFee),
                "Platform fee transfer failed"
            );
        }

        if (royaltyAmount > 0) {
            require(
                bifyToken.transfer(creator, royaltyAmount),
                "Royalty transfer failed"
            );

            emit RoyaltyPaid(creator, royaltyAmount);
        }

        uint256 sellerAmount = saleAmount.sub(platformFee).sub(royaltyAmount);
        require(
            bifyToken.transfer(auction.seller, sellerAmount),
            "Seller payment failed"
        );
    }

    /**
     * @dev Set query contract address
     * @param _queryContract Address of the query contract
     */
    function setQueryContract(address _queryContract) external onlyOwner {
        queryContract = MarketplaceQuery(_queryContract);
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
     * @dev Get the minimum royalty percentage for a collection
     * @param nftContract The NFT contract address
     * @return minRoyalty The minimum royalty percentage to enforce
     */
    function getMinimumRoyaltyForCollection(
        address nftContract
    ) public view returns (uint256 minRoyalty) {
        minRoyalty = minRoyaltyPercentage;

        if (
            IERC165(nftContract).supportsInterface(type(IERC2981).interfaceId)
        ) {
            try IERC2981(nftContract).royaltyInfo(0, 10000) returns (
                address,
                uint256 royaltyAmount
            ) {
                uint256 collectionRoyalty = (royaltyAmount * BASIS_POINTS) /
                    10000;
                if (collectionRoyalty > minRoyalty) {
                    minRoyalty = collectionRoyalty;
                }
            } catch {}
        }

        return minRoyalty;
    }

    /**
     * @dev Calculate total ETH locked in active auctions
     */
    function getLockedETH() public view returns (uint256 totalLocked) {
        for (uint256 i = 0; i < auctionIdCounter; i++) {
            Auction storage auction = auctions[i];
            if (
                auction.status == AuctionStatus.Active &&
                auction.paymentMethod == PaymentMethod.ETH &&
                auction.highestBid > 0
            ) {
                totalLocked += auction.highestBid;
            }
        }
        return totalLocked;
    }

    /**
     * @dev Calculate total BIFY tokens locked in active auctions
     */
    function getLockedBIFY() public view returns (uint256 totalLocked) {
        for (uint256 i = 0; i < auctionIdCounter; i++) {
            Auction storage auction = auctions[i];
            if (
                auction.status == AuctionStatus.Active &&
                auction.paymentMethod == PaymentMethod.BIFY &&
                auction.highestBid > 0
            ) {
                totalLocked += auction.highestBid;
            }
        }
        return totalLocked;
    }

    /**
     * @dev Emergency withdraw function for stuck ETH
     */
    function emergencyWithdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        uint256 lockedETH = getLockedETH();
        uint256 availableETH = balance > lockedETH ? balance - lockedETH : 0;

        require(availableETH > 0, "No available ETH to withdraw");

        (bool success, ) = msg.sender.call{value: availableETH}("");
        require(success, "Withdrawal failed");
    }

    /**
     * @dev Emergency withdraw function for stuck BIFY tokens
     */
    function emergencyWithdrawTokens() external onlyOwner {
        require(address(bifyToken) != address(0), "BIFY token not configured");

        uint256 balance = bifyToken.balanceOf(address(this));
        uint256 lockedBIFY = getLockedBIFY();
        uint256 availableBIFY = balance > lockedBIFY ? balance - lockedBIFY : 0;

        require(availableBIFY > 0, "No available tokens to withdraw");

        require(
            bifyToken.transfer(msg.sender, availableBIFY),
            "Token withdrawal failed"
        );
    }

    function updatePlatformFeePercentage(
        uint256 _newPercentage
    ) external onlyOwner {
        require(_newPercentage <= 100, "Fee cannot exceed 10%");
        uint256 oldPercentage = platformFeePercentage;
        platformFeePercentage = _newPercentage;
        emit PlatformFeePercentageUpdated(oldPercentage, _newPercentage);
    }

    function updatePlatformFeeRecipient(
        address _newRecipient
    ) external onlyOwner {
        require(_newRecipient != address(0), "Invalid recipient address");
        address oldRecipient = platformFeeRecipient;
        platformFeeRecipient = _newRecipient;
        emit PlatformFeeRecipientUpdated(oldRecipient, _newRecipient);
    }

    function updateStandardFeePercentage(
        uint256 _newPercentage
    ) external onlyOwner {
        require(_newPercentage <= 50, "Standard fee cannot exceed 5%");
        uint256 oldPercentage = standardPlatformFeePercentage;
        standardPlatformFeePercentage = _newPercentage;
        emit StandardFeePercentageUpdated(oldPercentage, _newPercentage);
    }

    function updateLaunchpadFeePercentage(
        uint256 _newPercentage
    ) external onlyOwner {
        require(_newPercentage <= 100, "Launchpad fee cannot exceed 10%");
        uint256 oldPercentage = launchpadPlatformFeePercentage;
        launchpadPlatformFeePercentage = _newPercentage;
        emit LaunchpadFeePercentageUpdated(oldPercentage, _newPercentage);
    }

    /**
     * @dev Set authorized registrar for launchpad collections
     * @param _registrar Address to authorize/unauthorize
     * @param _authorized Whether to authorize or revoke authorization
     */
    function setAuthorizedRegistrar(
        address _registrar,
        bool _authorized
    ) external onlyOwner {
        require(_registrar != address(0), "Invalid registrar address");
        authorizedRegistrars[_registrar] = _authorized;
        emit AuthorizedRegistrarUpdated(_registrar, _authorized);
    }

    /**
     * @dev Register a launchpad collection - callable by owner or authorized registrars
     * @param _collection Collection address to register
     */
    function registerLaunchpadCollection(address _collection) external {
        require(
            msg.sender == owner() || authorizedRegistrars[msg.sender],
            "Not authorized to register collections"
        );
        require(_collection != address(0), "Invalid collection address");
        launchpadCollections[_collection] = true;
        emit LaunchpadCollectionRegistered(_collection);
    }

    /**
     * @dev Unregister a launchpad collection - only owner can unregister
     * @param _collection Collection address to unregister
     */
    function unregisterLaunchpadCollection(
        address _collection
    ) external onlyOwner {
        require(_collection != address(0), "Invalid collection address");
        launchpadCollections[_collection] = false;
        emit LaunchpadCollectionUnregistered(_collection);
    }

    function isLaunchpadCollection(
        address _collection
    ) external view returns (bool) {
        return launchpadCollections[_collection];
    }

    /**
     * @dev Create a fixed price listing with ETH as payment
     * @param nftContract Address of the NFT contract
     * @param tokenId Token ID to list
     * @param price Price in ETH
     * @param assetType Asset type (NFT or RWA)
     * @param royaltyPercentage Royalty percentage (between min and max)
     * @param category Category for filtering
     * @return listingId The ID of the created listing
     */
    function createFixedPriceListing(
        address nftContract,
        uint256 tokenId,
        uint256 price,
        AssetType assetType,
        uint256 royaltyPercentage,
        bytes32 category
    ) external whenNotPaused nonReentrant returns (uint256 listingId) {
        require(nftContract != address(0), "Invalid NFT contract");
        require(price > 0, "Price must be > 0");
        uint256 collectionMinRoyalty = getMinimumRoyaltyForCollection(
            nftContract
        );
        require(
            royaltyPercentage >= collectionMinRoyalty &&
                royaltyPercentage <= maxRoyaltyPercentage,
            "Invalid royalty percentage"
        );

        IERC721(nftContract).transferFrom(msg.sender, address(this), tokenId);

        if (tokenCreators[nftContract][tokenId] == address(0)) {
            tokenCreators[nftContract][tokenId] = msg.sender;
        }

        listingId = listingIdCounter++;

        fixedPriceListings[listingId] = FixedPriceListing({
            seller: msg.sender,
            nftContract: nftContract,
            tokenId: tokenId,
            price: price,
            isActive: true,
            assetType: assetType,
            royaltyPercentage: royaltyPercentage,
            category: category,
            paymentMethod: PaymentMethod.ETH
        });

        if (address(queryContract) != address(0)) {
            queryContract.recordListing(
                listingId,
                msg.sender,
                nftContract,
                tokenId,
                price,
                uint8(assetType),
                royaltyPercentage,
                category
            );
        }

        emit FixedPriceListingCreated(
            listingId,
            msg.sender,
            nftContract,
            tokenId,
            price,
            assetType,
            royaltyPercentage,
            category,
            PaymentMethod.ETH
        );

        return listingId;
    }

    /**
     * @dev Buy a fixed price listing using ETH
     * @param listingId ID of the listing to purchase
     */
    function buyFixedPrice(
        uint256 listingId
    ) external payable nonReentrant whenNotPaused {
        FixedPriceListing storage listing = fixedPriceListings[listingId];

        require(listing.isActive, "Listing not active");
        require(
            listing.paymentMethod == PaymentMethod.ETH,
            "Not an ETH payment listing"
        );
        require(msg.value == listing.price, "Incorrect ETH amount");

        require(msg.sender != listing.seller, "Seller cannot buy");

        listing.isActive = false;

        _distributePayment(
            listing.price,
            payable(listing.seller),
            listing.nftContract,
            listing.tokenId,
            listing.royaltyPercentage
        );

        IERC721(listing.nftContract).transferFrom(
            address(this),
            msg.sender,
            listing.tokenId
        );

        if (address(queryContract) != address(0)) {
            queryContract.recordListingPurchased(listingId, msg.sender);
        }

        emit FixedPricePurchase(
            listingId,
            msg.sender,
            listing.price,
            PaymentMethod.ETH
        );
    }

    /**
     * @dev Create an auction with ETH as payment method
     */
    function createAuction(
        address nftContract,
        uint256 tokenId,
        uint256 reservePrice,
        uint256 buyNowPrice,
        uint256 startTime,
        uint256 duration,
        AssetType assetType,
        uint256 royaltyPercentage,
        bytes32 category
    ) external whenNotPaused nonReentrant returns (uint256 auctionId) {
        require(nftContract != address(0), "Invalid NFT contract");
        require(duration >= 1 hours, "Min duration 1 hour");
        require(duration <= 30 days, "Max duration 30 days");
        require(
            reservePrice > 0 || buyNowPrice > 0,
            "Reserve or buyNow must be > 0"
        );
        require(
            buyNowPrice == 0 || buyNowPrice >= reservePrice,
            "BuyNow must exceed reserve"
        );
        uint256 collectionMinRoyalty = getMinimumRoyaltyForCollection(
            nftContract
        );
        require(
            royaltyPercentage >= collectionMinRoyalty &&
                royaltyPercentage <= maxRoyaltyPercentage,
            "Invalid royalty percentage"
        );

        if (startTime == 0) {
            startTime = block.timestamp;
        } else {
            require(startTime >= block.timestamp, "Start time in past");
        }

        uint256 endTime = startTime + duration;

        IERC721(nftContract).transferFrom(msg.sender, address(this), tokenId);

        if (tokenCreators[nftContract][tokenId] == address(0)) {
            tokenCreators[nftContract][tokenId] = msg.sender;
        }

        auctionId = auctionIdCounter++;

        auctions[auctionId] = Auction({
            seller: msg.sender,
            nftContract: nftContract,
            tokenId: tokenId,
            reservePrice: reservePrice,
            buyNowPrice: buyNowPrice,
            startTime: startTime,
            endTime: endTime,
            highestBidder: address(0),
            highestBid: 0,
            isSettled: false,
            status: AuctionStatus.Active,
            royaltyPercentage: royaltyPercentage,
            assetType: assetType,
            category: category,
            paymentMethod: PaymentMethod.ETH
        });

        if (address(queryContract) != address(0)) {
            queryContract.recordAuction(
                auctionId,
                msg.sender,
                nftContract,
                tokenId,
                reservePrice,
                buyNowPrice,
                startTime,
                endTime,
                royaltyPercentage,
                uint8(assetType),
                category
            );
        }

        emit AuctionCreated(
            auctionId,
            msg.sender,
            nftContract,
            tokenId,
            reservePrice,
            buyNowPrice,
            startTime,
            endTime,
            assetType,
            royaltyPercentage,
            category,
            PaymentMethod.ETH
        );

        return auctionId;
    }

    /**
     * @dev Place a bid with ETH
     */
    function placeBid(
        uint256 auctionId
    ) external payable nonReentrant whenNotPaused {
        Auction storage auction = auctions[auctionId];

        require(auction.status == AuctionStatus.Active, "Auction not active");
        require(block.timestamp >= auction.startTime, "Auction not started");
        require(block.timestamp < auction.endTime, "Auction ended");
        require(msg.sender != auction.seller, "Seller cannot bid");
        require(
            auction.paymentMethod == PaymentMethod.ETH,
            "Not an ETH payment auction"
        );

        uint256 bidAmount = msg.value;

        if (auction.highestBid > 0) {
            uint256 minIncrement = (auction.highestBid *
                MIN_BID_INCREMENT_PERCENTAGE) / BASIS_POINTS;
            uint256 minBidAmount = auction.highestBid + minIncrement;
            require(bidAmount >= minBidAmount, "Bid increment too small");
        } else {
            require(bidAmount >= auction.reservePrice, "Below reserve price");
        }

        bool isBuyNow = false;
        if (auction.buyNowPrice > 0 && bidAmount >= auction.buyNowPrice) {
            bidAmount = auction.buyNowPrice;
            isBuyNow = true;
        }

        if (auction.highestBidder != address(0)) {
            pendingWithdrawals[auction.highestBidder] += auction.highestBid;
        }

        auction.highestBidder = msg.sender;
        auction.highestBid = bidAmount;

        bidHistory[auctionId].push(
            BidInfo({
                bidder: msg.sender,
                amount: bidAmount,
                timestamp: block.timestamp,
                paymentMethod: PaymentMethod.ETH
            })
        );

        bool extended = false;
        if (!isBuyNow && auction.endTime - block.timestamp < ANTI_SNIPE_TIME) {
            auction.endTime = block.timestamp + ANTI_SNIPE_TIME;
            extended = true;
            emit AuctionExtended(auctionId, auction.endTime);
        }

        if (address(queryContract) != address(0)) {
            queryContract.recordBid(auctionId, msg.sender, bidAmount);
        }

        emit BidPlaced(
            auctionId,
            msg.sender,
            bidAmount,
            extended,
            PaymentMethod.ETH
        );

        if (isBuyNow) {
            emit BuyNowPurchase(
                auctionId,
                msg.sender,
                auction.buyNowPrice,
                PaymentMethod.ETH
            );
            _settleAuction(auctionId);
        }
    }

    /**
     * @dev Buy an auction immediately with ETH
     */
    function buyNow(
        uint256 auctionId
    ) external payable nonReentrant whenNotPaused {
        Auction storage auction = auctions[auctionId];

        require(auction.status == AuctionStatus.Active, "Auction not active");
        require(block.timestamp >= auction.startTime, "Auction not started");
        require(block.timestamp < auction.endTime, "Auction ended");
        require(auction.buyNowPrice > 0, "No buy now price");
        require(
            auction.paymentMethod == PaymentMethod.ETH,
            "Not an ETH payment auction"
        );
        require(msg.value == auction.buyNowPrice, "Incorrect ETH amount");

        if (auction.highestBidder != address(0)) {
            pendingWithdrawals[auction.highestBidder] += auction.highestBid;
        }

        auction.highestBidder = msg.sender;
        auction.highestBid = auction.buyNowPrice;

        bidHistory[auctionId].push(
            BidInfo({
                bidder: msg.sender,
                amount: auction.buyNowPrice,
                timestamp: block.timestamp,
                paymentMethod: PaymentMethod.ETH
            })
        );

        if (address(queryContract) != address(0)) {
            queryContract.recordBid(auctionId, msg.sender, auction.buyNowPrice);
        }

        _settleAuction(auctionId);

        emit BuyNowPurchase(
            auctionId,
            msg.sender,
            auction.buyNowPrice,
            PaymentMethod.ETH
        );
    }

    /**
     * @dev Settle an auction that uses ETH
     */
    function settleAuction(
        uint256 auctionId
    ) external nonReentrant whenNotPaused {
        Auction storage auction = auctions[auctionId];

        require(
            auction.status == AuctionStatus.Active,
            "Auction not in active state"
        );
        require(block.timestamp > auction.endTime, "Auction not ended");
        require(!auction.isSettled, "Auction already settled");
        require(
            auction.paymentMethod == PaymentMethod.ETH,
            "Not an ETH payment auction"
        );

        _settleAuction(auctionId);
    }

    /**
     * @dev Internal function to settle an ETH-based auction
     */
    function _settleAuction(uint256 auctionId) internal {
        Auction storage auction = auctions[auctionId];

        auction.status = AuctionStatus.Ended;
        auction.isSettled = true;

        address winningBidder = auction.highestBidder;

        if (winningBidder != address(0)) {
            _distributePayment(
                auction.highestBid,
                payable(auction.seller),
                auction.nftContract,
                auction.tokenId,
                auction.royaltyPercentage
            );

            IERC721(auction.nftContract).transferFrom(
                address(this),
                winningBidder,
                auction.tokenId
            );

            if (address(queryContract) != address(0)) {
                queryContract.recordAuctionSettled(auctionId, winningBidder);
            }

            emit AuctionSettled(
                auctionId,
                winningBidder,
                auction.highestBid,
                PaymentMethod.ETH
            );
        } else {
            IERC721(auction.nftContract).transferFrom(
                address(this),
                auction.seller,
                auction.tokenId
            );

            if (address(queryContract) != address(0)) {
                queryContract.recordAuctionCanceled(auctionId);
            }

            emit AuctionCanceled(auctionId);
        }
    }

    /**
     * @dev Internal function to distribute ETH payments after sale
     */
    function _distributePayment(
        uint256 saleAmount,
        address payable seller,
        address nftContract,
        uint256 tokenId,
        uint256 royaltyPercentage
    ) internal {
        address creator = tokenCreators[nftContract][tokenId];

        // Determine fee percentage based on whether NFT is from launchpad
        uint256 feePercentage = launchpadCollections[nftContract]
            ? launchpadPlatformFeePercentage
            : standardPlatformFeePercentage;

        uint256 platformFee = saleAmount.mul(feePercentage).div(BASIS_POINTS);
        uint256 royaltyAmount = 0;

        if (creator != address(0) && creator != seller) {
            royaltyAmount = saleAmount.mul(royaltyPercentage).div(BASIS_POINTS);
        }

        if (platformFee > 0) {
            (bool feeSuccess, ) = platformFeeRecipient.call{value: platformFee}(
                ""
            );
            require(feeSuccess, "Platform fee transfer failed");
        }

        if (royaltyAmount > 0) {
            address payable creatorPayable = payable(creator);
            (bool royaltySuccess, ) = creatorPayable.call{value: royaltyAmount}(
                ""
            );
            require(royaltySuccess, "Royalty transfer failed");

            emit RoyaltyPaid(creator, royaltyAmount);
        }

        uint256 sellerAmount = saleAmount.sub(platformFee).sub(royaltyAmount);
        (bool sellerSuccess, ) = seller.call{value: sellerAmount}("");
        require(sellerSuccess, "Seller payment failed");
    }

    /**
     * @dev Cancel an auction - can only be done by seller if no bids yet
     */
    function cancelAuction(
        uint256 auctionId
    ) external nonReentrant whenNotPaused {
        Auction storage auction = auctions[auctionId];

        require(auction.status == AuctionStatus.Active, "Auction not active");
        require(auction.seller == msg.sender, "Not the seller");
        require(auction.highestBidder == address(0), "Bids already placed");

        auction.status = AuctionStatus.Canceled;

        IERC721(auction.nftContract).transferFrom(
            address(this),
            auction.seller,
            auction.tokenId
        );

        if (address(queryContract) != address(0)) {
            queryContract.recordAuctionCanceled(auctionId);
        }

        emit AuctionCanceled(auctionId);
    }

    /**
     * @dev Cancel a fixed price listing
     */
    function cancelFixedPriceListing(
        uint256 listingId
    ) external nonReentrant whenNotPaused {
        FixedPriceListing storage listing = fixedPriceListings[listingId];

        require(listing.isActive, "Listing not active");
        require(listing.seller == msg.sender, "Not the seller");

        listing.isActive = false;

        IERC721(listing.nftContract).transferFrom(
            address(this),
            listing.seller,
            listing.tokenId
        );

        if (address(queryContract) != address(0)) {
            queryContract.recordListingCanceled(listingId);
        }
    }

    /**
     * @dev Withdraw pending ETH payments (for refunded bids, etc.)
     */
    function withdraw() external nonReentrant {
        uint256 amount = pendingWithdrawals[msg.sender];
        require(amount > 0, "No funds to withdraw");

        pendingWithdrawals[msg.sender] = 0;

        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Transfer failed");

        emit WithdrawalMade(msg.sender, amount);
    }

    /**
     * @dev Set max bid for automatic bidding
     * @param auctionId Auction ID to bid on
     * @param maxBidAmount Maximum bid amount
     */
    function setMaxBid(
        uint256 auctionId,
        uint256 maxBidAmount
    ) external nonReentrant whenNotPaused {
        Auction storage auction = auctions[auctionId];

        require(auction.status == AuctionStatus.Active, "Auction not active");
        require(
            auction.paymentMethod == PaymentMethod.ETH,
            "Not an ETH payment auction"
        );
        require(maxBidAmount > auction.highestBid, "Max bid too low");

        maxBids[auctionId][msg.sender] = maxBidAmount;

        emit MaxBidSet(auctionId, msg.sender, maxBidAmount, PaymentMethod.ETH);
    }

    /**
     * @dev Edit an existing fixed price listing
     * @param listingId The ID of the listing to edit
     * @param newPrice The new price for the listing
     */
    function editFixedPriceListing(
        uint256 listingId,
        uint256 newPrice
    ) external whenNotPaused nonReentrant {
        FixedPriceListing storage listing = fixedPriceListings[listingId];

        require(listing.seller != address(0), "Listing does not exist");
        require(listing.isActive, "Listing is not active");

        require(listing.seller == msg.sender, "Only seller can edit listing");

        uint256 oldPrice = listing.price;

        listing.price = newPrice;

        if (address(queryContract) != address(0)) {
            queryContract.recordListingUpdated(listingId, newPrice);
        }

        emit FixedPriceListingEdited(listingId, oldPrice, newPrice);
    }

    /**
     * @dev Edit an existing auction
     * @param auctionId The ID of the auction to edit
     * @param newReservePrice The new reserve price for the auction
     * @param newBuyNowPrice The new buy now price for the auction
     */
    function editAuction(
        uint256 auctionId,
        uint256 newReservePrice,
        uint256 newBuyNowPrice
    ) external whenNotPaused nonReentrant {
        Auction storage auction = auctions[auctionId];

        require(auction.seller != address(0), "Auction does not exist");
        require(
            auction.status == AuctionStatus.Active,
            "Auction is not active"
        );

        require(auction.seller == msg.sender, "Only seller can edit auction");

        require(
            auction.highestBidder == address(0),
            "Cannot edit auction with bids"
        );

        uint256 oldReservePrice = auction.reservePrice;
        uint256 oldBuyNowPrice = auction.buyNowPrice;

        require(
            newBuyNowPrice > newReservePrice,
            "Buy now price must be greater than reserve price"
        );

        auction.reservePrice = newReservePrice;
        auction.buyNowPrice = newBuyNowPrice;

        if (address(queryContract) != address(0)) {
            queryContract.recordAuctionUpdated(
                auctionId,
                newReservePrice,
                newBuyNowPrice
            );
        }

        emit AuctionEdited(
            auctionId,
            oldReservePrice,
            newReservePrice,
            oldBuyNowPrice,
            newBuyNowPrice
        );
    }
}
