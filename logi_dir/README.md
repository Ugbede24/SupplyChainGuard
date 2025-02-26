# SupplyChainGuard

A robust smart contract system for secure and transparent supply chain management on the Stacks blockchain.

## Overview

SupplyChainGuard is a decentralized supply chain management system that facilitates trusted interactions between manufacturers, retailers, and quality inspectors. Built on the Stacks blockchain using Clarity smart contracts, it provides a secure and transparent way to manage shipments, handle disputes, and verify product authenticity.

## Features

- **Secure Shipment Creation**: Manufacturers can create shipment contracts with detailed specifications
- **Multi-Party Verification**: Three-way verification system involving manufacturers, retailers, and inspectors
- **Quality Dispute Resolution**: Built-in mechanism for handling and resolving quality issues
- **Product Authentication**: Secure product signature verification system
- **Automated Payments**: Smart contract-managed payment releases based on verification status
- **Deadline Management**: Automatic payment release system after deadline expiration
- **Cancellation Handling**: Secure process for shipment cancellation with appropriate refunds

## Smart Contract Functions

### Core Functions

- `create-shipment`: Initialize a new shipment contract
- `verify-shipment`: Allow parties to verify the shipment
- `complete-transaction`: Process the final payment after verifications
- `report-quality-issue`: Report quality problems with shipments
- `resolve-quality-issue`: Resolve reported quality disputes
- `verify-product`: Verify product authenticity using signatures

### Administrative Functions

- `cancel-shipment`: Cancel an active shipment
- `deadline-release`: Release payment after deadline expiration
- `add-product-signature`: Add product authentication signatures

## Data Structure

The contract maintains a map of shipment contracts with the following properties:

- Manufacturer and retailer principals
- Shipment value
- Contract status flags
- Verification status
- Quality dispute indicators
- Delivery deadline
- Product signature
- Shipping timestamp

## Security Features

- Role-based access control
- Secure payment handling
- Input validation
- Dispute resolution mechanism
- Product authentication
- Deadline enforcement

## Getting Started

### Prerequisites

- Stacks blockchain wallet
- Clarity development environment
- Access to Stacks testnet/mainnet

### Deployment

1. Clone this repository
2. Deploy the smart contract to the Stacks blockchain
3. Initialize the contract with required parameters
4. Start creating shipment contracts
