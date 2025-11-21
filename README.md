# 🎮 In-Game Asset Lending Smart Contract

> **Unlock the power of your idle gaming NFTs!** 💎

A decentralized lending protocol that enables players to monetize their valuable in-game NFTs through secure, time-locked rental agreements on the Stacks blockchain.

## 🚀 Overview

The In-Game Asset Lending contract addresses a key problem in gaming economies: players holding valuable NFT assets but unable to monetize them when not actively playing. This smart contract creates a marketplace where:

- 🏪 **Asset owners** can list their NFTs for rent and earn passive income
- 🎯 **Borrowers** can temporarily access rare/expensive assets they couldn't otherwise afford
- ⏱️ **Time-locked contracts** ensure automatic return of assets with built-in security
- 💰 **Automated payments** handle all transactions transparently

## ✨ Key Features

- **🔐 Secure Lending**: Time-locked contracts with automatic expiration
- **💳 Automated Payments**: STX-based rental fees with configurable rates
- **⚡ Flexible Duration**: Customizable lending periods (1 day to 1 year)
- **🛡️ Owner Protection**: Automatic asset reclaim after expiration
- **📊 User Management**: Track multiple loans and listings per user
- **🔧 Admin Controls**: Contract-level fee management and duration limits

## 🏗️ Contract Architecture

### Core Data Structures

- **Asset Listings**: NFT rental offers with pricing and duration
- **Active Loans**: Current borrowing agreements with timestamps
- **User Mappings**: Track individual user's loans and listings

### Key Functions

#### 📝 For Asset Owners

```clarity
(list-asset asset-contract asset-id daily-rate min-duration max-duration)
```
List your NFT for rent with custom pricing

```clarity
(update-listing listing-id daily-rate min-duration max-duration)
```
Modify your existing listing terms

```clarity
(delist-asset listing-id)
```
Remove your asset from the marketplace

```clarity
(claim-expired-asset loan-id)
```
Reclaim your asset after loan expiration

#### 🎯 For Borrowers

```clarity
(borrow-asset listing-id duration)
```
Rent an NFT for specified duration with automatic payment

```clarity
(return-asset loan-id)
```
Return the borrowed asset early

```clarity
(extend-loan loan-id additional-duration)
```
Extend your current loan with additional payment

#### 🔍 Read-Only Functions

```clarity
(get-asset-listing listing-id)
(get-active-loan loan-id)
(get-user-loans user)
(calculate-loan-cost daily-rate duration)
(is-loan-expired loan-id)
```

## 💻 Usage Instructions

### 🎪 Setting Up

1. **Deploy the contract** to Stacks testnet/mainnet
2. **Initialize** with default fee rate (5%) and duration limits (1 day - 1 year)

### 📋 Listing an Asset

```bash
# List your NFT for 100 STX per day, minimum 7 days, maximum 30 days
(contract-call? .in-game-asset-lending list-asset 
  'SP1234...CONTRACT 
  u1 
  u100000000  ;; 100 STX in microSTX
  u1008       ;; 7 days in blocks
  u4320)      ;; 30 days in blocks
```

### 🎮 Borrowing an Asset

```bash
# Borrow asset from listing #1 for 14 days
(contract-call? .in-game-asset-lending borrow-asset 
  u1          ;; listing ID
  u2016)      ;; 14 days in blocks
```

### 📊 Checking Status

```bash
# View listing details
(contract-call? .in-game-asset-lending get-asset-listing u1)

# Check your active loans
(contract-call? .in-game-asset-lending get-user-loans 'SP1234...YOUR-ADDRESS)

# Calculate rental cost
(contract-call? .in-game-asset-lending calculate-loan-cost u100000000 u2016)
```

## ⚙️ Configuration

### Contract Parameters

- **Fee Rate**: Default 5% (500 basis points), maximum 10%
- **Min Duration**: 144 blocks (~1 day)
- **Max Duration**: 52,560 blocks (~1 year)
- **Max User Loans**: 10 concurrent loans per user

### Block Time Conversion

- 1 day ≈ 144 blocks
- 1 week ≈ 1,008 blocks  
- 1 month ≈ 4,320 blocks
- 1 year ≈ 52,560 blocks

## 🔒 Security Features

- ✅ **Owner-only functions** for contract administration
- ✅ **Input validation** for all parameters
- ✅ **Automatic expiration** handling
- ✅ **Payment verification** before asset transfer
- ✅ **Duplicate listing prevention**
- ✅ **Borrower limits** to prevent spam

## 📈 Economic Model

### Fee Structure
- **Base Cost**: `daily-rate × duration`
- **Platform Fee**: `base-cost × fee-rate / 10,000`
- **Total Cost**: `base-cost + platform-fee`

### Example Calculation
- Daily rate: 100 STX
- Duration: 7 days
- Base cost: 700 STX
- Platform fee (5%): 35 STX
- **Total**: 735 STX

## 🛠️ Development

### Prerequisites
- [Clarinet](https://github.com/hirosystems/clarinet)
- Stacks CLI
- Node.js (for testing)

### Running Tests
```bash
npm install
npm test
```

### Local Development
```bash
clarinet console
clarinet check
clarinet integrate
```

## 📋 Error Codes

| Code | Error | Description |
|------|-------|-------------|
| 400  | `ERR_INVALID_AMOUNT` | Invalid payment or duration |
| 401  | `ERR_UNAUTHORIZED` | Access denied |
| 404  | `ERR_NOT_FOUND` | Asset or loan not found |
| 409  | `ERR_ALREADY_BORROWED` | Asset already listed/borrowed |
| 410  | `ERR_NOT_BORROWED` | Asset not currently borrowed |
| 411  | `ERR_EXPIRED` | Loan has expired |
| 412  | `ERR_NOT_EXPIRED` | Loan hasn't expired yet |
| 414  | `ERR_INVALID_DURATION` | Duration outside allowed limits |
| 415  | `ERR_ASSET_NOT_AVAILABLE` | Asset not available for rent |

## 🌟 Impact & Benefits

### For Players 🎮
- **Passive Income**: Earn from idle NFTs
- **Asset Access**: Use expensive items temporarily
- **Risk Reduction**: Try before buying expensive assets

### For Gaming Economy 🌐
- **Increased Liquidity**: More active NFT utilization
- **Market Efficiency**: Better price discovery
- **Accessibility**: Lower barrier to entry for rare items

### For Developers 🔧
- **New Revenue Streams**: Platform fees from transactions
- **Enhanced Engagement**: Players return for rental management
- **Community Building**: Shared asset experiences

## 🤝 Contributing

Contributions welcome! Please read our contributing guidelines and submit PRs for:
- 🐛 Bug fixes
- ✨ Feature enhancements
- 📚 Documentation improvements
- 🧪 Additional tests

## 📜 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🔗 Links

- **Stacks Explorer**: [View on explorer](https://explorer.stacks.co)
- **Clarinet Docs**: [Learn more about Clarinet](https://docs.hiro.so/clarinet)
- **Stacks.js**: [Frontend integration](https://docs.stacks.co/stacks.js)

---

**Built with ❤️ on Stacks** • **Making Gaming NFTs Liquid** 🚀
