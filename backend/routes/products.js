const express = require("express");
const router = express.Router();
const Product = require("../models/Product");
const User = require("../models/User"); // ✅ Import User Model to find recyclers
const authMiddleware = require("../middleware/auth");
const { ethers } = require("ethers");

// --- BLOCKCHAIN SETUP ---
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

// 1. ADD PRODUCT (Includes Image & Blockchain)
router.post("/addProduct", authMiddleware(["admin", "staff"]), async (req, res) => {
  try {
    const { id, name, expiry, image } = req.body;

    const expiryTimestamp = new Date(expiry).getTime();

    const newProduct = new Product({
      id,
      name,
      expiry: expiryTimestamp,
      recycled: false,
      image: image || ""
    });
    await newProduct.save();

    const contract = getContract();
    if (contract) {
      const tx = await contract.addProduct(id, name, expiryTimestamp);
      console.log(`Transaction sent: ${tx.hash}`);
    }

    res.json({ success: true, message: "Product added to Inventory & Blockchain" });

  } catch (err) {
    console.error(err);
    res.status(500).json({ success: false, error: err.message });
  }
});

// 2. GET ALL PRODUCTS (Dashboard)
router.get("/allProducts", authMiddleware(["admin", "staff", "recycler"]), async (req, res) => {
  try {
    const products = await Product.find();
    const currentTime = Date.now();
    const threeDays = 3 * 24 * 60 * 60 * 1000;

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
        expiry: new Date(p.expiry).toLocaleDateString(),
        status: status,
        recycled: p.recycled,
        image: p.image, // ✅ ADDED: Send image to frontend
        recyclingStatus: p.recyclingStatus
      };
    });

    res.json({ products: formattedProducts });

  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// 3. ADMIN: DIRECT RECYCLE (Quick Action)
router.post("/recycleProduct/:id", authMiddleware(["admin"]), async (req, res) => {
  try {
    const productId = req.params.id;
    const product = await Product.findOne({ id: productId });
    
    if (!product) return res.status(404).json({ error: "Product not found" });

    // Blockchain
    const contract = getContract();
    if (contract) {
      try {
        const tx = await contract.markAsRecycled(productId);
        console.log(`Recycle TX sent: ${tx.hash}`);
      } catch (txError) {
        console.error("Blockchain error:", txError);
      }
    }

    // Database
    product.recycled = true;
    product.recyclingStatus = "completed";
    await product.save();

    res.json({ success: true, message: "Product recycled" });

  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// --- ✅ NEW RECYCLER WORKFLOW ROUTES ---

// 4. GET AVAILABLE RECYCLERS (Admin)
router.get("/recyclers/list", authMiddleware(["admin"]), async (req, res) => {
  try {
    // Fetch users who registered as 'recycler' and are approved
    const recyclers = await User.find({ role: "recycler", isApproved: true }).select("name email");
    res.json({ recyclers });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// 5. ASSIGN RECYCLE TASK (Admin)
router.post("/assign-recycle/:id", authMiddleware(["admin"]), async (req, res) => {
  try {
    const { recyclerId } = req.body;
    const productId = req.params.id;

    await Product.findOneAndUpdate({ id: productId }, {
      assignedRecycler: recyclerId,
      recyclingStatus: "assigned",
      assignedDate: Date.now()
    });

    res.json({ success: true, message: "Task Assigned to Recycler" });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// 6. GET ASSIGNED TASKS (Recycler)
router.get("/recycler/tasks", authMiddleware(["recycler"]), async (req, res) => {
  try {
    const tasks = await Product.find({ 
      assignedRecycler: req.user.id, 
      recyclingStatus: "assigned" 
    });
    
    // Format basic data for recycler view
    const formattedTasks = tasks.map(t => ({
      id: t.id,
      name: t.name,
      expiry: new Date(t.expiry).toLocaleDateString(),
      image: t.image
    }));

    res.json({ tasks: formattedTasks });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// 7. COMPLETE TASK (Recycler -> Updates Blockchain)
router.post("/recycler/complete/:id", authMiddleware(["recycler"]), async (req, res) => {
  try {
    const product = await Product.findOne({ id: req.params.id });
    if (!product) return res.status(404).json({ error: "Product not found" });

    // A. Write to Blockchain
    const contract = getContract();
    if (contract) {
      try {
        const tx = await contract.markAsRecycled(product.id);
        console.log(`Blockchain Recycled by Worker: ${tx.hash}`);
      } catch (txError) {
        console.error("Blockchain error:", txError);
      }
    }

    // B. Update Database
    product.recyclingStatus = "completed";
    product.recycled = true;
    await product.save();

    res.json({ success: true, message: "Collection Completed!" });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;