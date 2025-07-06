# Bify Smart Contracts

This repository contains the complete smart contract ecosystem for the Bify NFT marketplace and launchpad platform. The contracts are designed to provide a comprehensive solution for NFT collection creation, marketplace operations, whitelist management, and payment processing.

## 📋 Table of Contents

- [Project Overview](#project-overview)
- [Architecture](#architecture)
- [Smart Contracts](#smart-contracts)
  - [Core Contracts](#core-contracts)
  - [Marketplace Contracts](#marketplace-contracts)
  - [Collection Contracts](#collection-contracts)
  - [Whitelist Management](#whitelist-management)
  - [Payment System](#payment-system)
  - [Query Contracts](#query-contracts)
  - [Storage Contracts](#storage-contracts)
  - [Libraries](#libraries)
  - [Interfaces](#interfaces)
- [Contract Interactions](#contract-interactions)
- [Frontend Integration](#frontend-integration)
- [Backend Integration](#backend-integration)
- [Deployment](#deployment)
- [Usage Examples](#usage-examples)
- [Security Features](#security-features)
- [Gas Optimization](#gas-optimization)
- [Testing](#testing)
- [Development](#development)

## 🎯 Project Overview

The Bify platform is a comprehensive NFT ecosystem that combines:

- **NFT Launchpad**: For creators to launch their collections with advanced features
- **NFT Marketplace**: For trading NFTs with auction and fixed-price listings
- **Whitelist Management**: Advanced tiered whitelist system
- **Payment Processing**: Support for both ETH and BIFY token payments
- **Query System**: Efficient data retrieval for frontend applications

## 🏗️ Architecture

The Bify smart contract system follows a modular architecture with clear separation of concerns:

```
┌─────────────────────────────────────────────────────────────────┐
│                        Frontend (Next.js)                       │
├─────────────────────────────────────────────────────────────────┤
│                        Backend (Node.js)                        │
├─────────────────────────────────────────────────────────────────┤
│                      Smart Contracts                            │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐ │
│  │   Launchpad     │  │   Marketplace   │  │   Collections   │ │
│  │    System       │  │     System      │  │     System      │ │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘ │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐ │
│  │   Whitelist     │  │    Payment      │  │     Query       │ │
│  │   Management    │  │    System       │  │    System       │ │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

## 📄 Smart Contracts

### Core Contracts

#### 1. BifyLaunchpad.sol

**Purpose**: Main entry point and facade for the launchpad system
**Key Features**:

- Coordinates between core, phase, and query components
- Enforces authorization for all launchpad operations
- Handles collection creation with various configurations
- Manages platform fees and payments

**Main Functions**:

```solidity
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
) external payable returns (address)

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
) external payable returns (address)
```

#### 2. BifyLaunchpadCore.sol

**Purpose**: Core business logic for launchpad operations
**Key Features**:

- Collection registration and management
- Creator authorization and validation
- Platform fee processing
- Integration with collection factory

**Usage**: Called by BifyLaunchpad facade to handle core operations

#### 3. BifyLaunchpadPhase.sol

**Purpose**: Manages minting phases and time-based restrictions
**Key Features**:

- Public and whitelist phase management
- Time-based access control
- Phase-specific pricing and limits
- Dynamic phase updates

### Marketplace Contracts

#### 1. BifyMarketplace.sol

**Purpose**: Complete marketplace for NFT trading
**Key Features**:

- Auction system with anti-sniping protection
- Fixed-price listings
- Bid-to-earn mechanics
- Royalty distribution
- Multi-payment method support (ETH/BIFY)

**Main Functions**:

```solidity
function createAuction(
    address _nftContract,
    uint256 _tokenId,
    uint256 _reservePrice,
    uint256 _buyNowPrice,
    uint256 _duration,
    uint256 _royaltyPercentage,
    AssetType _assetType,
    bytes32 _category,
    PaymentMethod _paymentMethod
) external returns (uint256)

function createFixedPriceListing(
    address _nftContract,
    uint256 _tokenId,
    uint256 _price,
    uint256 _royaltyPercentage,
    AssetType _assetType,
    bytes32 _category,
    PaymentMethod _paymentMethod
) external returns (uint256)

function placeBid(uint256 _auctionId, PaymentMethod _paymentMethod) external payable
```

#### 2. MarketplaceQuery.sol

**Purpose**: Efficient data retrieval for marketplace operations
**Key Features**:

- Batch data fetching
- Filtered queries by category, price, status
- Pagination support
- Statistics calculation

### Collection Contracts

#### 1. NFTCollection.sol

**Purpose**: ERC721 implementation with advanced features
**Key Features**:

- Multiple reveal strategies (Standard, Blind Box, Randomized, Dynamic)
- Whitelist and public minting
- Royalty support (ERC2981)
- Batch minting capabilities
- Dynamic metadata evolution

**Reveal Strategies**:

- **STANDARD**: Immediate reveal upon minting
- **BLIND_BOX**: Hidden until reveal time
- **RANDOMIZED**: Random token ID assignment
- **DYNAMIC**: Evolving metadata over time

#### 2. BifyNFT.sol

**Purpose**: Enhanced NFT contract with additional features
**Key Features**:

- Advanced metadata management
- Creator tools integration
- Marketplace compatibility
- Gas-optimized operations

### Whitelist Management

#### 1. WhitelistManagerExtended.sol

**Purpose**: Advanced whitelist system with tiered access
**Key Features**:

- Multi-tier whitelist support (Tier 1, 2, 3)
- Time-based access windows
- Merkle tree verification
- Direct whitelist management
- Per-tier pricing and limits

**Tier Structure**:

```solidity
struct Tier {
    bytes32 merkleRoot;
    uint256 startTime;
    uint256 endTime;
    uint256 maxMintsPerWallet;
    uint256 price;
    bool active;
}
```

#### 2. WhitelistManagerFactory.sol

**Purpose**: Factory for creating whitelist managers
**Key Features**:

- Standardized whitelist creation
- Template-based deployment
- Cost-efficient deployment

### Payment System

#### 1. BifyTokenPayment.sol

**Purpose**: Handles BIFY token payments across the platform
**Key Features**:

- ETH to BIFY conversion
- Platform fee collection
- Multi-token support
- Rate management

**Key Functions**:

```solidity
function processPayment(
    address _from,
    address _to,
    uint256 _amount,
    bytes32 _paymentId
) external returns (bool)

function ethToBify(uint256 _ethAmount) public view returns (uint256)
function bifyToEth(uint256 _bifyAmount) public view returns (uint256)
```

### Query Contracts

#### 1. BifyLaunchpadQuery.sol

**Purpose**: Efficient data retrieval for launchpad operations
**Key Features**:

- Collection metadata queries
- Creator information retrieval
- Phase status checking
- Batch data fetching

#### 2. BifyLaunchpadQueryBase.sol

**Purpose**: Base contract for query operations
**Key Features**:

- Common query patterns
- Data structure definitions
- Error handling

#### 3. MarketplaceQueryLibrary.sol

**Purpose**: Library for marketplace data queries
**Key Features**:

- Optimized query functions
- Data aggregation
- Statistical calculations

### Storage Contracts

#### 1. BifyLaunchpadStorage.sol

**Purpose**: Centralized storage for launchpad data
**Key Features**:

- Collection registry
- Creator mappings
- Authorization management
- Platform configuration

### Libraries

#### 1. BifyCollectionFactory.sol

**Purpose**: Factory library for creating NFT collections
**Key Features**:

- Standardized collection deployment
- Parameter validation
- Gas-optimized creation

#### 2. BifyCollectionRegistry.sol

**Purpose**: Registry for tracking collections
**Key Features**:

- Collection indexing
- Creator tracking
- Category management

#### 3. BifyPaymentManager.sol

**Purpose**: Payment processing utilities
**Key Features**:

- Fee calculations
- Payment validation
- Multi-currency support

#### 4. BifyQueryLibrary.sol

**Purpose**: Common query operations
**Key Features**:

- Data aggregation
- Filtering utilities
- Pagination helpers

#### 5. MarketplaceValidation.sol

**Purpose**: Validation logic for marketplace operations
**Key Features**:

- Input validation
- Business rule enforcement
- Security checks

### Interfaces

#### 1. IBifyLaunchpadCore.sol

**Purpose**: Interface for core launchpad operations

#### 2. IBifyLaunchpadPhase.sol

**Purpose**: Interface for phase management

#### 3. IBifyLaunchpadQuery.sol

**Purpose**: Interface for query operations

#### 4. IBifyLaunchpadStorage.sol

**Purpose**: Interface for storage operations

#### 5. IWhitelistManagerExtended.sol

**Purpose**: Interface for whitelist management

## 🔄 Contract Interactions

### Collection Creation Flow

```
User → BifyLaunchpad → BifyLaunchpadCore → BifyCollectionFactory → NFTCollection
                    ↓
                BifyLaunchpadStorage (registration)
                    ↓
                WhitelistManagerExtended (if whitelist enabled)
```

### Marketplace Trading Flow

```
User → BifyMarketplace → NFTCollection (ownership verification)
                      ↓
                   BifyTokenPayment (if BIFY payment)
                      ↓
                   Royalty Distribution
```

### Query Operations Flow

```
Frontend → MarketplaceQuery → BifyMarketplace (data retrieval)
        ↓
    BifyLaunchpadQuery → BifyLaunchpadStorage (collection data)
```

## 🌐 Frontend Integration

The frontend (Next.js) integrates with smart contracts through:

### Contract Configuration

```typescript
// contracts.ts
export const marketplaceContractConfig = {
  address: MARKETPLACE_ADDRESS,
  abi: BifyMarketplaceABI,
};

export const launchpadContractConfig = {
  address: LAUNCHPAD_ADDRESS,
  abi: BifyLaunchpadABI,
};
```

### Key Integration Points

1. **Collection Creation**: Forms interface with BifyLaunchpad
2. **Marketplace Operations**: Trading interface with BifyMarketplace
3. **Whitelist Management**: Admin interface with WhitelistManagerExtended
4. **Query Operations**: Data fetching through query contracts

## 🔧 Backend Integration

The backend (Node.js) serves as middleware between frontend and blockchain:

### Key Services

1. **Launchpad Service**: Handles collection deployment and management
2. **Marketplace Service**: Processes trading operations
3. **Whitelist Service**: Manages whitelist operations
4. **Query Service**: Aggregates blockchain data

### Example Backend Integration

```javascript
// launchpad-blockchain.service.js
const deployCollection = async (collectionData, creatorAddress) => {
  const launchpadContract = new ethers.Contract(
    LAUNCHPAD_CONTRACT_ADDRESS,
    bifyLaunchpadABI,
    wallet
  );

  const tx = await launchpadContract.createCollection(
    collectionData.name,
    collectionData.symbol,
    collectionData.maxSupply
    // ... other parameters
  );

  return await tx.wait();
};
```

## 🚀 Deployment

### Prerequisites

```bash
npm install
cp env.example .env
# Edit .env with your configuration
```

### Network Configuration

The contracts support multiple networks:

- **Hardhat Network**: Local development
- **Base Sepolia**: Testnet
- **Base Mainnet**: Production
- **Ethereum Sepolia**: Testnet
- **Ethereum Mainnet**: Production

### Deployment Commands

```bash
# Compile contracts
npm run compile

# Deploy to testnet
npm run deploy:base-sepolia

# Deploy to mainnet
npm run deploy:base

# Verify contracts
npx hardhat verify --network baseSepolia CONTRACT_ADDRESS
```

## 📖 Usage Examples

### Creating a Collection

```solidity
// Simple collection
address collection = launchpad.createCollection(
    "My Collection",
    "MYC",
    1000,  // maxSupply
    500,   // 5% royalty
    "ipfs://baseuri/",
    block.timestamp + 3600,  // start in 1 hour
    block.timestamp + 86400, // end in 24 hours
    0.01 ether,  // price
    10,     // max per wallet
    "art",  // category
    false   // use ETH payment
);
```

### Creating an Auction

```solidity
uint256 auctionId = marketplace.createAuction(
    nftContract,
    tokenId,
    0.1 ether,  // reserve price
    1 ether,    // buy now price
    86400,      // 24 hour duration
    500,        // 5% royalty
    AssetType.NFT,
    "art",
    PaymentMethod.ETH
);
```

### Whitelist Management

```solidity
// Create tier
uint256 tierId = whitelist.createTier(
    merkleRoot,
    startTime,
    endTime,
    5,          // max mints per wallet
    0.05 ether  // tier price
);

// Add to direct whitelist
whitelist.addToDirectWhitelist(userAddress, TierLevel.Tier1);
```

## 🔒 Security Features

### Access Control

- **Ownable**: Admin functions protected
- **ReentrancyGuard**: Protection against reentrancy attacks
- **Pausable**: Emergency pause functionality

### Validation

- Input validation on all public functions
- Business rule enforcement
- Overflow protection with SafeMath

### Authorization

- Multi-level authorization system
- Role-based access control
- Creator verification

## ⛽ Gas Optimization

### Techniques Used

1. **Batch Operations**: Multiple operations in single transaction
2. **Packed Structs**: Efficient storage layout
3. **View Functions**: Gas-free data retrieval
4. **Event Optimization**: Efficient event emission

## 🛠️ Development

### Project Structure

```
bify-contract/
├── contracts/           # Smart contract source files
│   ├── interfaces/     # Contract interfaces
│   ├── libraries/      # Utility libraries
│   ├── storage/        # Storage contracts
│   └── *.sol          # Main contracts
├── test/               # Test files
├── scripts/            # Deployment scripts
├── hardhat.config.js   # Hardhat configuration
└── package.json        # Dependencies
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Implement changes with tests
4. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

---

_This README provides a comprehensive overview of the Bify smart contract ecosystem. For detailed implementation examples and API references, please refer to the individual contract files and their NatSpec documentation._
