# Community Treasury Management DAO

A decentralized autonomous organization for transparent community treasury fund allocation and governance.

## Overview

The Community Treasury DAO enables token holders to propose, vote on, and manage treasury fund allocations through a democratic governance process. All decisions are made transparently on-chain with weighted voting based on governance token holdings.

## Key Features

- **Democratic Fund Allocation**: Community members can propose treasury spending initiatives
- **Weighted Voting System**: Voting power proportional to governance token holdings
- **Transparent Process**: All proposals and votes recorded on-chain
- **Delegation Support**: Token holders can delegate voting power to trusted representatives
- **Quorum Requirements**: Minimum participation thresholds ensure legitimate decision-making

## Smart Contract Functions

### Administrative
- `distribute-governance-tokens`: Mint governance tokens to community members
- `submit-treasury-allocation`: Create new funding proposals
- `cast-allocation-vote`: Vote on active proposals
- `finalize-allocation`: Execute completed proposals that meet quorum

### Query Functions
- `get-allocation-details`: Retrieve proposal information
- `get-member-vote`: Check individual voting records
- `get-governance-balance`: View token holdings
- `get-total-allocations`: Get total number of proposals

## Governance Parameters

- **Minimum Proposal Tokens**: 2,500 tokens required to create proposals
- **Voting Period**: 14 days (2,016 blocks)
- **Quorum Threshold**: 10,000 total votes required for proposal execution

## Security Features

- Input validation for all parameters
- Protection against double voting
- Time-based voting windows
- Quorum requirements for legitimacy
- Access control for administrative functions

## Usage

1. Acquire governance tokens through community distribution
2. Create proposals for treasury fund allocation
3. Participate in voting on active proposals
4. Delegate voting power if desired
5. Execute approved proposals after voting period

## Development

Built with Clarity smart contract language for the Stacks blockchain, ensuring security and transparency in all governance operations.
