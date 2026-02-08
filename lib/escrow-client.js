#!/usr/bin/env node
// TrustBridge Escrow Client
// Uses viem for contract interaction

const { createPublicClient, createWalletClient, http, formatUnits, parseUnits } = require('viem');
const { privateKeyToAccount } = require('viem/accounts');
const { baseSepolia } = require('viem/chains');
const config = require('./config');

// Minimal ABI for TrustBridgeEscrow contract
const ESCROW_ABI = [
  {
    name: 'createEscrow',
    type: 'function',
    stateMutability: 'nonpayable',
    inputs: [
      { name: 'provider', type: 'address' },
      { name: 'amount', type: 'uint256' },
      { name: 'description', type: 'string' }
    ],
    outputs: [{ type: 'bytes32' }]
  },
  {
    name: 'acceptEscrow',
    type: 'function',
    stateMutability: 'nonpayable',
    inputs: [{ name: 'id', type: 'bytes32' }],
    outputs: []
  },
  {
    name: 'releaseEscrow',
    type: 'function',
    stateMutability: 'nonpayable',
    inputs: [{ name: 'id', type: 'bytes32' }],
    outputs: []
  },
  {
    name: 'refundEscrow',
    type: 'function',
    stateMutability: 'nonpayable',
    inputs: [{ name: 'id', type: 'bytes32' }],
    outputs: []
  },
  {
    name: 'getEscrow',
    type: 'function',
    stateMutability: 'view',
    inputs: [{ name: 'id', type: 'bytes32' }],
    outputs: [{
      type: 'tuple',
      components: [
        { name: 'id', type: 'bytes32' },
        { name: 'client', type: 'address' },
        { name: 'provider', type: 'address' },
        { name: 'amount', type: 'uint256' },
        { name: 'description', type: 'string' },
        { name: 'status', type: 'uint8' },
        { name: 'createdAt', type: 'uint256' },
        { name: 'updatedAt', type: 'uint256' }
      ]
    }]
  },
  {
    name: 'getUserEscrows',
    type: 'function',
    stateMutability: 'view',
    inputs: [{ name: 'user', type: 'address' }],
    outputs: [{ type: 'bytes32[]' }]
  }
];

// ERC20 ABI for USDC approval
const ERC20_ABI = [
  {
    name: 'approve',
    type: 'function',
    stateMutability: 'nonpayable',
    inputs: [
      { name: 'spender', type: 'address' },
      { name: 'amount', type: 'uint256' }
    ],
    outputs: [{ type: 'bool' }]
  },
  {
    name: 'allowance',
    type: 'function',
    stateMutability: 'view',
    inputs: [
      { name: 'owner', type: 'address' },
      { name: 'spender', type: 'address' }
    ],
    outputs: [{ type: 'uint256' }]
  }
];

// Status enum mapping
const STATUS_MAP = ['PENDING', 'ACTIVE', 'COMPLETED', 'REFUNDED', 'DISPUTED'];

class EscrowClient {
  constructor(privateKey, network = config.defaultNetwork) {
    const networkConfig = config.networks[network];
    if (!networkConfig) throw new Error(`Unknown network: ${network}`);
    if (!networkConfig.contract) throw new Error('Contract address not configured. Set TRUSTBRIDGE_CONTRACT env var.');
    
    this.network = networkConfig;
    this.account = privateKeyToAccount(privateKey);
    
    this.publicClient = createPublicClient({
      chain: baseSepolia,
      transport: http(networkConfig.rpc)
    });
    
    this.walletClient = createWalletClient({
      account: this.account,
      chain: baseSepolia,
      transport: http(networkConfig.rpc)
    });
  }

  // Parse USDC amount (human readable -> wei)
  parseUSDC(amount) {
    return parseUnits(amount.toString(), config.usdcDecimals);
  }

  // Format USDC amount (wei -> human readable)
  formatUSDC(amount) {
    return formatUnits(amount, config.usdcDecimals);
  }

  // Approve USDC spending
  async approveUSDC(amount) {
    const hash = await this.walletClient.writeContract({
      address: this.network.usdc,
      abi: ERC20_ABI,
      functionName: 'approve',
      args: [this.network.contract, amount]
    });
    await this.publicClient.waitForTransactionReceipt({ hash });
    return hash;
  }

  // Create a new escrow
  async createEscrow(provider, amount, description) {
    const amountWei = this.parseUSDC(amount);
    
    // First approve USDC
    await this.approveUSDC(amountWei);
    
    // Create escrow
    const hash = await this.walletClient.writeContract({
      address: this.network.contract,
      abi: ESCROW_ABI,
      functionName: 'createEscrow',
      args: [provider, amountWei, description]
    });
    
    const receipt = await this.publicClient.waitForTransactionReceipt({ hash });
    
    // Extract escrow ID from logs (first topic of EscrowCreated event after filtering)
    const escrowId = receipt.logs[1]?.topics[1] || receipt.logs[0]?.topics[1];
    
    return {
      txHash: hash,
      escrowId,
      amount,
      provider,
      description,
      explorer: `${this.network.explorer}/tx/${hash}`
    };
  }

  // Accept an escrow (as provider)
  async acceptEscrow(escrowId) {
    const hash = await this.walletClient.writeContract({
      address: this.network.contract,
      abi: ESCROW_ABI,
      functionName: 'acceptEscrow',
      args: [escrowId]
    });
    
    await this.publicClient.waitForTransactionReceipt({ hash });
    
    return {
      txHash: hash,
      escrowId,
      explorer: `${this.network.explorer}/tx/${hash}`
    };
  }

  // Release escrow funds (as client)
  async releaseEscrow(escrowId) {
    const hash = await this.walletClient.writeContract({
      address: this.network.contract,
      abi: ESCROW_ABI,
      functionName: 'releaseEscrow',
      args: [escrowId]
    });
    
    await this.publicClient.waitForTransactionReceipt({ hash });
    
    return {
      txHash: hash,
      escrowId,
      explorer: `${this.network.explorer}/tx/${hash}`
    };
  }

  // Refund escrow (as client, before acceptance)
  async refundEscrow(escrowId) {
    const hash = await this.walletClient.writeContract({
      address: this.network.contract,
      abi: ESCROW_ABI,
      functionName: 'refundEscrow',
      args: [escrowId]
    });
    
    await this.publicClient.waitForTransactionReceipt({ hash });
    
    return {
      txHash: hash,
      escrowId,
      explorer: `${this.network.explorer}/tx/${hash}`
    };
  }

  // Get escrow details
  async getEscrow(escrowId) {
    const escrow = await this.publicClient.readContract({
      address: this.network.contract,
      abi: ESCROW_ABI,
      functionName: 'getEscrow',
      args: [escrowId]
    });
    
    return {
      id: escrow.id,
      client: escrow.client,
      provider: escrow.provider,
      amount: this.formatUSDC(escrow.amount),
      amountRaw: escrow.amount.toString(),
      description: escrow.description,
      status: STATUS_MAP[escrow.status] || 'UNKNOWN',
      statusCode: escrow.status,
      createdAt: new Date(Number(escrow.createdAt) * 1000).toISOString(),
      updatedAt: new Date(Number(escrow.updatedAt) * 1000).toISOString()
    };
  }

  // List user's escrows
  async listEscrows(address) {
    address = address || this.account.address;
    
    const escrowIds = await this.publicClient.readContract({
      address: this.network.contract,
      abi: ESCROW_ABI,
      functionName: 'getUserEscrows',
      args: [address]
    });
    
    const escrows = await Promise.all(
      escrowIds.map(id => this.getEscrow(id))
    );
    
    return escrows;
  }
}

module.exports = { EscrowClient, STATUS_MAP };

// CLI interface
if (require.main === module) {
  const args = process.argv.slice(2);
  const command = args[0];
  
  const privateKey = process.env.TRUSTBRIDGE_PRIVATE_KEY;
  if (!privateKey) {
    console.error('Error: TRUSTBRIDGE_PRIVATE_KEY not set');
    process.exit(1);
  }
  
  const client = new EscrowClient(privateKey);
  
  async function run() {
    switch (command) {
      case 'create':
        const [, amount, provider, ...descParts] = args;
        const description = descParts.join(' ').replace(/^["']|["']$/g, '');
        const result = await client.createEscrow(provider, parseFloat(amount), description);
        console.log(JSON.stringify(result, null, 2));
        break;
        
      case 'accept':
        const acceptResult = await client.acceptEscrow(args[1]);
        console.log(JSON.stringify(acceptResult, null, 2));
        break;
        
      case 'release':
        const releaseResult = await client.releaseEscrow(args[1]);
        console.log(JSON.stringify(releaseResult, null, 2));
        break;
        
      case 'refund':
        const refundResult = await client.refundEscrow(args[1]);
        console.log(JSON.stringify(refundResult, null, 2));
        break;
        
      case 'status':
        const escrow = await client.getEscrow(args[1]);
        console.log(JSON.stringify(escrow, null, 2));
        break;
        
      case 'list':
        const escrows = await client.listEscrows(args[1]);
        console.log(JSON.stringify(escrows, null, 2));
        break;
        
      default:
        console.error('Usage: escrow-client.js <create|accept|release|refund|status|list> [args]');
        process.exit(1);
    }
  }
  
  run().catch(err => {
    console.error('Error:', err.message);
    process.exit(1);
  });
}
