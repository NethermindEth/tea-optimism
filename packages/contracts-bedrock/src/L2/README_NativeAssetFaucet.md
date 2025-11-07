# NativeAssetFaucet - CGT Devnet Faucet

Simple faucet contract for Custom Gas Token (CGT) devnets that allows both permissionless and owner-controlled token minting.

## Contract Overview

The NativeAssetFaucet is an immutable contract that provides two ways to mint CGT tokens:

1. **Permissionless Claims**: Any user can claim a fixed amount of tokens once per block
2. **Owner Minting**: The owner can mint any amount to any address

### Features

- Immutable design (no upgrades needed)
- Per-block rate limiting for permissionless claims
- Owner can adjust permissionless claim amount
- Supports L1→L2 cross-chain calls via address aliasing
- No events (relies on LiquidityController events)

## Contract Details

- **Location**: `src/L2/NativeAssetFaucet.sol`
- **Deployment Address**: `0x8bcE16Ef26038f8EF673C3261a44230523014D4b` (example)
- **Owner**: Configurable at deployment time
- **Predeploy**: LiquidityController at `0x420000000000000000000000000000000000002a`

## Setup Instructions

### 1. Enable CGT Mode in op-up

First, modify `op-up/main.go` to enable Custom Gas Token support:

```go
// Add import
import (
    // ... other imports
    "math/big"
)

// In the opts configuration (around line 149)
sysgo.WithDeployerOptions(
    //...
    sysgo.WithCustomGasToken(true, "TestToken", "TST", new(big.Int).Mul(big.NewInt(1000000), big.NewInt(1e18))),
    //...
),
```

### 2. Build and Start op-up

```bash
# Navigate to op-up directory
cd op-up

just clean

just artifacts

just op-up

# Start op-up
./op-up
```

After starting, note the following addresses from the output:

- **Test Account Address**: `0x5D284fe6D6AEb73857960a0D041CF394b1198392`
- **Test Account Private Key**: `0xd9fb56b9574ed61ab0478a607166eeb3a80b1b91ab1bf00f45932105d07b5e11`
- **L2 ProxyAdmin Owner**: `0x2Def9f34f2b68B667Df303D23EDe392BD36Fb177`
- **L2 ProxyAdmin Owner Private Key**: `0xc24de1e962c31c8341cdae2b25b3e435d374b433a429d42c8c2398af1ffca3f9`
- **L1 Node URL**: `http://127.0.0.1:8544`
- **L2 Node URL**: `http://127.0.0.1:8545`

### 3. Deploy NativeAssetFaucet

```bash
cd packages/contracts-bedrock

# Build the contract
forge build

# Get the bytecode with constructor args
BYTECODE=$(forge inspect src/L2/NativeAssetFaucet.sol:NativeAssetFaucet bytecode)
CONSTRUCTOR_ARGS=$(cast abi-encode "constructor(address,uint256)" 0x2Def9f34f2b68B667Df303D23EDe392BD36Fb177 1000000000000000000)
DEPLOYMENT_DATA="${BYTECODE}${CONSTRUCTOR_ARGS:2}"

# Deploy the contract
cast send --rpc-url http://127.0.0.1:8545 \
  --private-key 0xd9fb56b9574ed61ab0478a607166eeb3a80b1b91ab1bf00f45932105d07b5e11 \
  --create "$DEPLOYMENT_DATA"
```

Note the `contractAddress` from the output (e.g., `0x8bcE16Ef26038f8EF673C3261a44230523014D4b`).

### 4. Authorize the Faucet as Minter

The faucet needs to be authorized to mint tokens via the LiquidityController.

First, fund the L2 ProxyAdmin Owner:

```bash
# Send 10 ETH to ProxyAdmin Owner
cast send 0x2Def9f34f2b68B667Df303D23EDe392BD36Fb177 \
  --value 10ether \
  --rpc-url http://127.0.0.1:8545 \
  --private-key 0xd9fb56b9574ed61ab0478a607166eeb3a80b1b91ab1bf00f45932105d07b5e11
```

Then authorize the faucet:

```bash
# Authorize NativeAssetFaucet as minter
cast send 0x420000000000000000000000000000000000002a \
  "authorizeMinter(address)" \
  0x8bcE16Ef26038f8EF673C3261a44230523014D4b \
  --rpc-url http://127.0.0.1:8545 \
  --private-key 0xc24de1e962c31c8341cdae2b25b3e435d374b433a429d42c8c2398af1ffca3f9
```

## Usage

### Permissionless Claim (Directly on L2)

Any user can claim tokens once per block:

```bash
# Check balance before
cast balance 0x5D284fe6D6AEb73857960a0D041CF394b1198392 --rpc-url http://127.0.0.1:8545

# Claim tokens
cast send 0x8bcE16Ef26038f8EF673C3261a44230523014D4b \
  "claim(address)" \
  0x5D284fe6D6AEb73857960a0D041CF394b1198392 \
  --rpc-url http://127.0.0.1:8545 \
  --private-key 0xd9fb56b9574ed61ab0478a607166eeb3a80b1b91ab1bf00f45932105d07b5e11

# Check balance after (should increase by 1 ETH)
cast balance 0x5D284fe6D6AEb73857960a0D041CF394b1198392 --rpc-url http://127.0.0.1:8545
```

### Owner Mint

The owner can mint any amount to any address:

```bash
# Mint 5 ETH to a specific address
cast send 0x8bcE16Ef26038f8EF673C3261a44230523014D4b \
  "mint(address,uint256)" \
  0x1234567890123456789012345678901234567890 \
  5000000000000000000 \
  --rpc-url http://127.0.0.1:8545 \
  --private-key 0xc24de1e962c31c8341cdae2b25b3e435d374b433a429d42c8c2398af1ffca3f9
```

### Adjust Permissionless Amount

The owner can change the per-block claim amount:

```bash
# Set permissionless amount to 2 ETH
cast send 0x8bcE16Ef26038f8EF673C3261a44230523014D4b \
  "setPermissionlessAmount(uint256)" \
  2000000000000000000 \
  --rpc-url http://127.0.0.1:8545 \
  --private-key 0xc24de1e962c31c8341cdae2b25b3e435d374b433a429d42c8c2398af1ffca3f9
```

## Cross-Chain Claims (L1 → L2)

You can trigger claims from L1 using deposit transactions. This is useful for testing cross-chain functionality and address aliasing.

### Step 1: Get L1 Contract Addresses

```bash
# Get L1 CrossDomainMessenger address from L2
L1_CDM=$(cast call 0x4200000000000000000000000000000000000007 \
  "l1CrossDomainMessenger()(address)" \
  --rpc-url http://127.0.0.1:8545)

echo "L1 CrossDomainMessenger: $L1_CDM"

# Get OptimismPortal address from L1 CrossDomainMessenger
PORTAL=$(cast call $L1_CDM \
  "portal()(address)" \
  --rpc-url http://127.0.0.1:8544)

echo "OptimismPortal2: $PORTAL"
```

Expected output:

- L1 CrossDomainMessenger: `0x4bcbCB1791C647aEF4773588B179a7c71D28c8c8`
- OptimismPortal2: `0x6d64C3fC032AD26FD2Df92B712C8A6c4F8C7eA02`

### Step 2: Create Calldata for Claim

```bash
# Create calldata for claim(address) function
CALLDATA=$(cast calldata "claim(address)" 0x5D284fe6D6AEb73857960a0D041CF394b1198392)

echo "Calldata: $CALLDATA"
# Output: 0x1e83409a0000000000000000000000005d284fe6d6aeb73857960a0d041cf394b1198392
```

### Step 3: Send Deposit Transaction from L1

```bash
# Check balance before
cast balance 0x5D284fe6D6AEb73857960a0D041CF394b1198392 --rpc-url http://127.0.0.1:8545

# Send deposit transaction from L1
cast send 0x6d64C3fC032AD26FD2Df92B712C8A6c4F8C7eA02 \
  "depositTransaction(address,uint256,uint64,bool,bytes)" \
  0x8bcE16Ef26038f8EF673C3261a44230523014D4b \
  0 \
  200000 \
  false \
  0x1e83409a0000000000000000000000005d284fe6d6aeb73857960a0d041cf394b1198392 \
  --rpc-url http://127.0.0.1:8544 \
  --private-key 0xd9fb56b9574ed61ab0478a607166eeb3a80b1b91ab1bf00f45932105d07b5e11

# Wait for L2 processing (about 10-15 seconds)
sleep 15

# Check balance after (should increase by 1 ETH)
cast balance 0x5D284fe6D6AEb73857960a0D041CF394b1198392 --rpc-url http://127.0.0.1:8545
```

**Parameters Explanation:**

- `_to`: `0x8bcE16Ef26038f8EF673C3261a44230523014D4b` - NativeAssetFaucet address
- `_value`: `0` - No ETH value (CGT mode doesn't allow msg.value)
- `_gasLimit`: `200000` - Gas limit for L2 execution
- `_isCreation`: `false` - Not a contract creation
- `_data`: `0x1e83409a...` - Encoded call to `claim(address)`

## Verification Commands

### Check CGT Status

```bash
# Verify CGT is enabled
cast call 0x4200000000000000000000000000000000000015 \
  "isCustomGasToken()(bool)" \
  --rpc-url http://127.0.0.1:8545
# Should return: true

# Check LiquidityController implementation
cast call 0x420000000000000000000000000000000000002a \
  "implementation()(address)" \
  --rpc-url http://127.0.0.1:8545
# Should return non-zero address
```

### Check Faucet Configuration

```bash
# Get owner address
cast call 0x8bcE16Ef26038f8EF673C3261a44230523014D4b \
  "owner()(address)" \
  --rpc-url http://127.0.0.1:8545

# Get permissionless amount
cast call 0x8bcE16Ef26038f8EF673C3261a44230523014D4b \
  "permissionlessAmount()(uint256)" \
  --rpc-url http://127.0.0.1:8545

# Check last claim block for an address
cast call 0x8bcE16Ef26038f8EF673C3261a44230523014D4b \
  "lastClaimBlock(address)(uint256)" \
  0x5D284fe6D6AEb73857960a0D041CF394b1198392 \
  --rpc-url http://127.0.0.1:8545
```

## Contract Interface

### Functions

#### `claim(address _to) external`

Permissionless function that allows anyone to claim tokens for any address once per block.

- Reverts if the address has already claimed in the current block
- Mints `permissionlessAmount` to `_to`

#### `mint(address _to, uint256 _amount) external onlyOwner`

Owner-only function to mint any amount of tokens to any address.

- Only callable by owner or aliased owner
- No rate limits

#### `setPermissionlessAmount(uint256 _amount) external onlyOwner`

Owner-only function to adjust the permissionless claim amount.

- Only callable by owner or aliased owner

### State Variables

#### `address public immutable owner`

The owner of the faucet. Can be an L1 address (will accept both normal and aliased calls).

#### `uint256 public permissionlessAmount`

The amount of tokens users can claim per block via the permissionless `claim()` function.

#### `mapping(address => uint256) public lastClaimBlock`

Tracks the last block number at which each address claimed tokens.

## Important Notes

1. **CGT Mode Requirement**: This faucet only works when Custom Gas Token mode is enabled
2. **Rate Limiting**: The rate limit is per recipient address (`_to`), not per caller (`msg.sender`)
3. **No Events**: The faucet doesn't emit events; check LiquidityController events instead
4. **Address Aliasing**: L1 addresses calling from contracts will be aliased when executing on L2
5. **Immutable**: Once deployed, the contract cannot be upgraded (owner cannot be changed)

## Troubleshooting

### "Proxy: implementation not initialized"

This means CGT mode is not enabled. Verify:

1. `WithCustomGasToken()` is added to op-up/main.go
2. op-up was rebuilt after the change
3. `~/.op-up` directory was cleaned before restart

### "NativeAssetFaucet_Unauthorized"

The caller is not the owner or aliased owner. Verify:

- Using the correct private key (L2 ProxyAdmin Owner)
- If calling from L1, the aliased address is correct

### "NativeAssetFaucet_BlockLimitReached"

The address has already claimed in the current block. Wait for the next block.

### Deposit transaction doesn't process

Wait 10-15 seconds for L2 to process the deposit. Check latest block with:

```bash
cast block latest --rpc-url http://127.0.0.1:8545 --json | jq '.number'
```

## Architecture Diagram

```
L1                                  L2
┌──────────────────┐               ┌──────────────────────┐
│ OptimismPortal2  │──deposit tx──>│ NativeAssetFaucet    │
└──────────────────┘               │  - claim()           │
                                   │  - mint()            │
                                   └──────────┬───────────┘
                                              │
                                              │ mint()
                                              ▼
                                   ┌──────────────────────┐
                                   │ LiquidityController  │
                                   │  (Predeploy 0x2a)    │
                                   └──────────────────────┘
```

## Testing Checklist

- [x] Deploy NativeAssetFaucet to L2
- [x] Authorize faucet as minter in LiquidityController
- [x] Test permissionless `claim()` directly on L2
- [x] Test owner `mint()` function
- [x] Test `setPermissionlessAmount()`
- [x] Test L1→L2 claim via depositTransaction
- [x] Verify rate limiting (per-block)
- [x] Verify address aliasing works correctly

## License

MIT
