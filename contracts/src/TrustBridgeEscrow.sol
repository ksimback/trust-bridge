// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract TrustBridgeEscrow is ReentrancyGuard {
    using SafeERC20 for IERC20;
    
    enum Status { Pending, Active, Completed, Refunded, Disputed }
    
    struct Escrow {
        bytes32 id;
        address client;
        address provider;
        uint256 amount;
        string description;
        Status status;
        uint256 createdAt;
        uint256 updatedAt;
    }
    
    IERC20 public immutable usdc;
    
    mapping(bytes32 => Escrow) public escrows;
    mapping(address => bytes32[]) public userEscrows;
    
    event EscrowCreated(bytes32 indexed id, address indexed client, address indexed provider, uint256 amount);
    event EscrowAccepted(bytes32 indexed id, address indexed provider);
    event EscrowReleased(bytes32 indexed id, address indexed provider, uint256 amount);
    event EscrowRefunded(bytes32 indexed id, address indexed client, uint256 amount);
    
    constructor(address _usdc) {
        usdc = IERC20(_usdc);
    }
    
    function createEscrow(
        address provider,
        uint256 amount,
        string calldata description
    ) external nonReentrant returns (bytes32) {
        require(amount > 0, "Amount must be > 0");
        require(provider != address(0), "Invalid provider");
        require(provider != msg.sender, "Cannot escrow to self");
        
        bytes32 id = keccak256(abi.encodePacked(
            msg.sender, provider, amount, block.timestamp, block.number
        ));
        
        usdc.safeTransferFrom(msg.sender, address(this), amount);
        
        escrows[id] = Escrow({
            id: id,
            client: msg.sender,
            provider: provider,
            amount: amount,
            description: description,
            status: Status.Pending,
            createdAt: block.timestamp,
            updatedAt: block.timestamp
        });
        
        userEscrows[msg.sender].push(id);
        userEscrows[provider].push(id);
        
        emit EscrowCreated(id, msg.sender, provider, amount);
        return id;
    }
    
    function acceptEscrow(bytes32 id) external nonReentrant {
        Escrow storage escrow = escrows[id];
        require(escrow.id != bytes32(0), "Escrow not found");
        require(escrow.provider == msg.sender, "Not the provider");
        require(escrow.status == Status.Pending, "Not pending");
        
        escrow.status = Status.Active;
        escrow.updatedAt = block.timestamp;
        
        emit EscrowAccepted(id, msg.sender);
    }
    
    function releaseEscrow(bytes32 id) external nonReentrant {
        Escrow storage escrow = escrows[id];
        require(escrow.id != bytes32(0), "Escrow not found");
        require(escrow.client == msg.sender, "Not the client");
        require(escrow.status == Status.Active, "Not active");
        
        escrow.status = Status.Completed;
        escrow.updatedAt = block.timestamp;
        
        usdc.safeTransfer(escrow.provider, escrow.amount);
        
        emit EscrowReleased(id, escrow.provider, escrow.amount);
    }
    
    function refundEscrow(bytes32 id) external nonReentrant {
        Escrow storage escrow = escrows[id];
        require(escrow.id != bytes32(0), "Escrow not found");
        require(escrow.client == msg.sender, "Not the client");
        require(escrow.status == Status.Pending, "Cannot refund after acceptance");
        
        escrow.status = Status.Refunded;
        escrow.updatedAt = block.timestamp;
        
        usdc.safeTransfer(escrow.client, escrow.amount);
        
        emit EscrowRefunded(id, escrow.client, escrow.amount);
    }
    
    function getEscrow(bytes32 id) external view returns (Escrow memory) {
        return escrows[id];
    }
    
    function getUserEscrows(address user) external view returns (bytes32[] memory) {
        return userEscrows[user];
    }
}
