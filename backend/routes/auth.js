const express = require("express");
const router = express.Router();
const jwt = require("jsonwebtoken");
const User = require("../models/User");
const authMiddleware = require("../middleware/auth"); // Reuse your existing middleware

// REGISTER (Public - Always Staff, Always Pending)
router.post("/register", async (req, res) => {
  try {
    const { name, email, password } = req.body;
    
    // Check if user exists
    const exists = await User.findOne({ email });
    if (exists) return res.status(400).json({ success: false, message: "User already exists" });

    // Force Role to Staff and Not Approved
    const user = new User({ 
      name, 
      email, 
      password, 
      role: "staff", 
      isApproved: false 
    });
    
    await user.save();
    res.json({ success: true, message: "Registered. Please wait for Admin approval." });
  } catch (err) {
    res.status(400).json({ success: false, message: err.message });
  }
});

// LOGIN (Strict Check)
router.post("/login", async (req, res) => {
  try {
    const { email, password } = req.body;
    const user = await User.findOne({ email });
    if (!user) return res.status(400).json({ message: "User not found" });

    // 🔒 CHECK APPROVAL
    if (user.isApproved === false) {
      return res.status(403).json({ message: "Account pending approval from Admin." });
    }

    const isMatch = await user.comparePassword(password);
    if (!isMatch) return res.status(400).json({ message: "Incorrect password" });

    const token = jwt.sign({ id: user._id, role: user.role }, process.env.JWT_SECRET, { expiresIn: "7d" });
    
    // Return role so app knows which dashboard to show
    res.json({ success: true, token, role: user.role });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// --- ADMIN ROUTES ---

// GET PENDING STAFF
router.get("/admin/pending-users", authMiddleware(["admin"]), async (req, res) => {
  try {
    // Find users who are NOT approved
    const users = await User.find({ isApproved: false }).select("-password");
    res.json({ users });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// APPROVE STAFF
router.post("/admin/approve-user", authMiddleware(["admin"]), async (req, res) => {
  try {
    const { userId } = req.body;
    await User.findByIdAndUpdate(userId, { isApproved: true });
    res.json({ success: true, message: "User Approved!" });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;