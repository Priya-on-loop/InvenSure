const express = require("express");
const router = express.Router();
const jwt = require("jsonwebtoken");
const User = require("../models/User");
const authMiddleware = require("../middleware/auth");

// 1. REGISTER
router.post("/register", async (req, res) => {
  try {
    const { name, email, password } = req.body;
    
    // Check if email OR name already exists (Unique names required now)
    const exists = await User.findOne({ $or: [{ email }, { name }] });
    if (exists) return res.status(400).json({ success: false, message: "User/Email exists" });

    const user = new User({ name, email, password, role: "staff", isApproved: false });
    await user.save();
    res.json({ success: true, message: "Registered. Wait for Approval." });
  } catch (err) {
    res.status(400).json({ success: false, message: err.message });
  }
});

// 2. LOGIN (Email OR Name Feature)
router.post("/login", async (req, res) => {
  try {
    // We expect 'email' field from frontend, but it could be a name
    const { email, password } = req.body; 
    
    // ✅ Logic: Find by Email OR Find by Name
    const user = await User.findOne({ 
      $or: [{ email: email }, { name: email }] 
    });

    if (!user) return res.status(400).json({ message: "User not found" });

    if (user.isApproved === false) {
      return res.status(403).json({ message: "Account Pending Approval." });
    }

    const isMatch = await user.comparePassword(password);
    if (!isMatch) return res.status(400).json({ message: "Incorrect password" });

    const token = jwt.sign({ id: user._id, role: user.role }, process.env.JWT_SECRET, { expiresIn: "1d" });
    res.json({ success: true, token, role: user.role });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// 3. ADMIN: Get Users (Modified to accept a query)
router.get("/admin/users", authMiddleware(["admin"]), async (req, res) => {
  try {
    // If query param 'type' is 'active', get active users. Else get pending.
    const filter = req.query.type === 'active' ? { isApproved: true } : { isApproved: false };
    const users = await User.find(filter).select("-password");
    res.json({ users });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// 4. ADMIN: Approve
router.post("/admin/approve", authMiddleware(["admin"]), async (req, res) => {
  try {
    const { userId } = req.body;
    await User.findByIdAndUpdate(userId, { isApproved: true });
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// 5. ADMIN: Delete Staff (✅ NEW FEATURE)
router.post("/admin/delete", authMiddleware(["admin"]), async (req, res) => {
  try {
    const { userId } = req.body;
    // Prevent Admin from deleting themselves!
    if(req.user.id === userId) return res.status(400).json({ message: "Cannot delete yourself" });
    
    await User.findByIdAndDelete(userId);
    res.json({ success: true, message: "User Deleted" });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;