const express = require("express");
const router = express.Router();
const jwt = require("jsonwebtoken");
const User = require("../models/User");
const authMiddleware = require("../middleware/auth"); // Reusing your existing middleware

// 1. REGISTER (Public)
// Logic: Always 'Staff', Always 'Not Approved'
router.post("/register", async (req, res) => {
  try {
    const { name, email, password } = req.body;
    
    const exists = await User.findOne({ email });
    if (exists) return res.status(400).json({ success: false, message: "User exists" });

    const user = new User({ 
      name, 
      email, 
      password,
      role: "staff",      // Forced
      isApproved: false   // Locked
    });
    
    await user.save();
    res.json({ success: true, message: "Registration successful. Please wait for Admin approval." });
  } catch (err) {
    res.status(400).json({ success: false, message: err.message });
  }
});

// 2. LOGIN (Strict)
router.post("/login", async (req, res) => {
  try {
    const { email, password } = req.body;
    const user = await User.findOne({ email });
    if (!user) return res.status(400).json({ message: "User not found" });

    // 🔒 SECURITY GATE: Check if Admin approved them
    if (user.isApproved === false) {
      return res.status(403).json({ message: "Account pending approval. Contact Admin." });
    }

    const isMatch = await user.comparePassword(password);
    if (!isMatch) return res.status(400).json({ message: "Incorrect password" });

    const token = jwt.sign({ id: user._id, role: user.role }, process.env.JWT_SECRET, { expiresIn: "1d" });
    res.json({ success: true, token, role: user.role });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// 3. ADMIN: Get List of Pending Users
router.get("/admin/pending", authMiddleware(["admin"]), async (req, res) => {
  try {
    const users = await User.find({ isApproved: false }).select("-password");
    res.json({ users });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// 4. ADMIN: Approve a User
router.post("/admin/approve", authMiddleware(["admin"]), async (req, res) => {
  try {
    const { userId } = req.body;
    await User.findByIdAndUpdate(userId, { isApproved: true });
    res.json({ success: true, message: "User Approved" });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;