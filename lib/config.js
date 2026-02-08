// TrustBridge Configuration
// Network settings and contract addresses

module.exports = {
  networks: {
    'base-sepolia': {
      chainId: 84532,
      rpc: 'https://sepolia.base.org',
      usdc: '0x036CbD53842c5426634e7929541eC2318f3dCF7e',
      contract: process.env.TRUSTBRIDGE_CONTRACT || null, // Set after deployment
      explorer: 'https://sepolia.basescan.org'
    }
  },
  defaultNetwork: process.env.TRUSTBRIDGE_NETWORK || 'base-sepolia',
  
  // USDC has 6 decimals
  usdcDecimals: 6
};
