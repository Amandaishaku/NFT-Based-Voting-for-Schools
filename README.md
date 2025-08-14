# 🗳️ NFT-Based Voting for Schools

A decentralized voting system that allows parents to vote on school policies using NFTs as voting tokens. Each NFT represents one vote, ensuring fair and transparent decision-making in educational institutions.

## 🌟 Features

- 🎫 **NFT-Based Voting**: Each parent receives an NFT that serves as their voting token
- 📝 **Proposal Management**: School administrators can create proposals for policy changes
- ⚡ **Real-time Voting**: Parents can vote on active proposals using their NFTs
- 📊 **Transparent Results**: All votes and results are publicly verifiable on the blockchain
- 🔒 **Secure & Immutable**: Votes cannot be changed once cast, ensuring election integrity
- 👥 **Bulk Registration**: Efficient registration of multiple parents at once

## 🚀 Quick Start

### Prerequisites

- [Clarinet](https://github.com/hirosystems/clarinet) installed
- Stacks wallet for testing

### Installation

1. Clone the repository:
```bash
git clone <repository-url>
cd NFT-Based-Voting-for-Schools
```

2. Install dependencies:
```bash
npm install
```

3. Start Clarinet console:
```bash
clarinet console
```

## 📋 Usage Instructions

### For School Administrators

#### 1. 🎯 Mint Voter NFTs
Register parents and mint their voting NFTs:

```clarity
(contract-call? .NFT-based-Voting mint-voter-nft 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM "John Smith" "Lincoln Elementary")
```

#### 2. 📊 Bulk Mint NFTs
Register multiple parents at once:

```clarity
(contract-call? .NFT-based-Voting bulk-mint-nfts 
  (list 
    {recipient: 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM, name: "John Smith", school: "Lincoln Elementary"}
    {recipient: 'ST2JHG361ZXG51QTKY2NQCVBPPRRE2KZB1HR05NNC, name: "Jane Doe", school: "Lincoln Elementary"}
  )
)
```

#### 3. 📝 Create Proposals
Create new voting proposals:

```clarity
(contract-call? .NFT-based-Voting create-proposal 
  "New Lunch Menu Policy" 
  "Proposal to introduce healthier options in the school cafeteria including organic vegetables and whole grain options"
  u1440) ;; Voting duration in blocks (approximately 10 days)
```

#### 4. ✅ Finalize Proposals
Close voting and determine results:

```clarity
(contract-call? .NFT-based-Voting finalize-proposal u1)
```

### For Parents (Voters)

#### 1. 🗳️ Cast Your Vote
Vote on active proposals using your NFT:

```clarity
(contract-call? .NFT-based-Voting vote-on-proposal u1 true u1) ;; proposal-id, vote (true=yes, false=no), token-id
```

#### 2. 📊 Check Voting Status
See if you can vote on a proposal:

```clarity
(contract-call? .NFT-based-Voting can-vote u1 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)
```

### For Everyone

#### 📈 View Proposal Details
```clarity
(contract-call? .NFT-based-Voting get-proposal u1)
```

#### 📊 Get Proposal Statistics
```clarity
(contract-call? .NFT-based-Voting get-proposal-stats u1)
```

#### 👤 Check Voter Information
```clarity
(contract-call? .NFT-based-Voting get-voter-info 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)
```

#### 🏆 View Contract Statistics
```clarity
(contract-call? .NFT-based-Voting get-contract-stats)
```

## 🏗️ Smart Contract Architecture

### Core Components

- **📦 NFT Token**: `school-voter-nft` - Non-fungible tokens representing voting rights
- **📋 Proposals**: Stored with title, description, voting period, and results
- **🗳️ Votes**: Mapped to voters and proposals with vote choice and token used
- **👥 Voter Info**: Parent registration data including name and school

### Key Functions

| Function | Description | Access |
|----------|-------------|---------|
| `mint-voter-nft` | 🎫 Register parent and mint voting NFT | Admin only |
| `create-proposal` | 📝 Create new voting proposal | Admin only |
| `vote-on-proposal` | 🗳️ Cast vote using NFT | NFT holders |
| `finalize-proposal` | ✅ Close voting and determine result | Admin only |
| `get-proposal-stats` | 📊 View proposal voting statistics | Public |

## 🔐 Security Features

- ✅ **Ownership Verification**: Only NFT owners can vote
- ✅ **One Vote Per NFT**: Each NFT can only vote once per proposal
- ✅ **Time-Bounded Voting**: Proposals have defined start and end blocks
- ✅ **Admin Controls**: Only contract owner can create proposals and mint NFTs
- ✅ **Immutable Votes**: Votes cannot be changed once cast

## 🧪 Testing

Run the test suite:

```bash
clarinet test
```

Run specific tests:

```bash
npm run test
```

## 📄 Error Codes

| Code | Description |
|------|-------------|
| `u100` | Owner only operation |
| `u101` | Not token owner |
| `u102` | Proposal not found |
| `u103` | Voting period ended |
| `u104` | Already voted |
| `u105` | Invalid vote |
| `u106` | Proposal still active |
| `u107` | Insufficient votes |

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📞 Support

For questions or support, please open an issue in the GitHub repository.

## 📄 License

This project is open source and available under the MIT License.

---

**Built with ❤️ for transparent and democratic school governance**
