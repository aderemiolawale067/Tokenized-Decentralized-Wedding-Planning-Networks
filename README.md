# Tokenized Decentralized Wedding Planning Network

A comprehensive blockchain-based wedding planning platform built on Stacks using Clarity smart contracts.

## Overview

This decentralized wedding planning network provides a complete solution for managing wedding events through smart contracts, ensuring transparency, trust, and automated coordination between all parties involved.

## Core Contracts

### 1. Vendor Verification Contract (\`vendor-verification.clar\`)
- Validates wedding service provider credentials
- Manages vendor registration and reputation scores
- Handles credential verification and endorsements
- Tracks vendor performance metrics

### 2. Budget Allocation Contract (\`budget-allocation.clar\`)
- Manages expense distribution across wedding categories
- Tracks spending limits and actual expenses
- Handles payment releases and refunds
- Provides budget reporting and analytics

### 3. Guest Coordination Contract (\`guest-coordination.clar\`)
- Handles invitation responses and guest management
- Manages seating arrangements and table assignments
- Tracks dietary restrictions and special requirements
- Coordinates guest communication

### 4. Timeline Synchronization Contract (\`timeline-synchronization.clar\`)
- Coordinates all wedding day activities
- Manages vendor schedules and dependencies
- Handles timeline updates and notifications
- Ensures proper sequencing of events

### 5. Conflict Resolution Contract (\`conflict-resolution.clar\`)
- Mediates disputes between couples and vendors
- Manages arbitration processes
- Handles refund and compensation claims
- Provides resolution tracking and reporting

## Features

- **Decentralized Trust**: All transactions and agreements are recorded on-chain
- **Automated Payments**: Smart contract-based payment releases
- **Reputation System**: Vendor rating and review mechanism
- **Dispute Resolution**: Built-in mediation and arbitration
- **Real-time Coordination**: Synchronized planning and execution
- **Transparent Budgeting**: Clear expense tracking and allocation

## Token Economics

The platform uses a native token for:
- Payment processing
- Vendor staking and reputation
- Governance and voting
- Incentive mechanisms

## Getting Started

1. Deploy contracts to Stacks testnet/mainnet
2. Initialize wedding planning session
3. Register vendors and validate credentials
4. Set up budget allocation and guest coordination
5. Synchronize timeline and manage activities

## Testing

Run tests using Vitest:

\`\`\`bash
npm test
\`\`\`

## Contract Interactions

Each contract operates independently without cross-contract calls, ensuring modularity and security. All contracts follow Clarity best practices and include comprehensive error handling.

## Security Considerations

- No cross-contract dependencies
- Input validation on all functions
- Access control mechanisms
- Overflow protection
- Reentrancy prevention

## License

MIT License - see LICENSE file for details
