const express = require("express");
const router = express.Router();
const Product = require("../models/Product");
const authMiddleware = require("../middleware/auth");
const { ethers } = require("ethers");

// --- BLOCKCHAIN SETUP ---
// We use the variables from your .env file
const RPC_URL = process.env.RPC_URL;
const PRIVATE_KEY = process.env.PRIVATE_KEY;
const CONTRACT_ADDRESS = process.env.CONTRACT_ADDRESS;

// Simple ABI based on your ExpiryTracker.sol
const CONTRACT_ABI = [
  "function addProduct(uint256 _productId, string memory _name, uint256 _expiryDate) public",
  "function markAsRecycled(uint256 _productId) public"
];

// Helper to get Contract
const getContract = () => {
  try {
    const provider = new ethers.JsonRpcProvider(RPC_URL);
    const wallet = new ethers.Wallet(PRIVATE_KEY, provider);
    return new ethers.Contract(CONTRACT_ADDRESS, CONTRACT_ABI, wallet);
  } catch (error) {
    console.error("Blockchain connection error:", error);
    return null;
  }
};

// --- ROUTES ---

// 1. ADD PRODUCT
// Endpoint: POST /addProduct
router.post("/addProduct", authMiddleware(["admin", "staff"]), async (req, res) => {
  try {
    const { id, name, expiry, image } = req.body;

    // 1. Convert Date String (YYYY-MM-DD) to Timestamp (Number)
    const expiryTimestamp = new Date(expiry).getTime();

    // 2. Save to MongoDB
    const newProduct = new Product({
      id,
      name,
      expiry: expiryTimestamp,
      recycled: false,
      image: image || ""
    });
    await newProduct.save();

    // 3. Save to Blockchain (Fire and forget, or await if strict)
    const contract = getContract();
    if (contract) {
      // Note: Blockchain takes seconds, we assume it works to keep UI fast
      // In production, use a queue system
      const tx = await contract.addProduct(id, name, expiryTimestamp);
      console.log(`Transaction sent: ${tx.hash}`);
    }

    res.json({ success: true, message: "Product added to Inventory & Blockchain" });

  } catch (err) {
    console.error(err);
    res.status(500).json({ success: false, error: err.message });
  }
});

// 2. GET ALL PRODUCTS
// Endpoint: GET /allProducts
router.get("/allProducts", authMiddleware(["admin", "staff"]), async (req, res) => {
  try {
    const products = await Product.find();
    const currentTime = Date.now();
    const threeDays = 3 * 24 * 60 * 60 * 1000;

    // Transform data for Frontend (Add 'status' field)
    const formattedProducts = products.map((p) => {
      let status = "Fresh";
      
      if (p.recycled) {
        status = "Recycled";
      } else if (currentTime > p.expiry) {
        status = "Expired";
      } else if (p.expiry - currentTime < threeDays) {
        status = "Near Expiry";
      }

      return {
        id: p.id,
        name: p.name,
        // Convert timestamp back to readable date for UI
        expiry: new Date(p.expiry).toLocaleDateString(), 
        status: status, 
        recycled: p.recycled
      };
    });

    res.json({ products: formattedProducts });

  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// 3. RECYCLE PRODUCT
// Endpoint: POST /recycleProduct/:id
router.post("/recycleProduct/:id", authMiddleware(["admin"]), async (req, res) => {
  try {
    const productId = req.params.id;

    // 1. Update MongoDB
    const product = await Product.findOne({ id: productId });
    if (!product) return res.status(404).json({ error: "Product not found" });

    product.recycled = true;
    await product.save();

    // 2. Update Blockchain
    const contract = getContract();
    if (contract) {
      const tx = await contract.markAsRecycled(productId);
      console.log(`Recycle TX sent: ${tx.hash}`);
    }

    res.json({ success: true, message: "Product recycled" });

  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

module.exports = router;