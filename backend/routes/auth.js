const express = require("express");
const router = express.Router();
const jwt = require("jsonwebtoken");
const User = require("../models/User");
const authMiddleware = require("../middleware/auth");

// 1. REGISTER
router.post("/register", async (req, res) => {
  try {
    const { name, email, password, role } = req.body;
    
    // Check if user exists (Email OR Name must be unique)
    const exists = await User.findOne({ $or: [{ email }, { name }] });
    if (exists) return res.status(400).json({ success: false, message: "User exists" });

    // Validate role: Allow 'staff' or 'recycler', default to 'staff'
    let userRole = "staff";
    if (role === "recycler") userRole = "recycler";

    const user = new User({ 
      name, 
      email, 
      password,
      role: userRole, 
      isApproved: false // Always locked until admin approves
    });
    
    await user.save();
    res.json({ success: true, message: "Registered. Wait for Approval." });
  } catch (err) {
    res.status(400).json({ success: false, message: err.message });
  }
});

// 2. LOGIN (Email OR Name)
router.post("/login", async (req, res) => {
  try {
    const { email, password } = req.body; // 'email' field holds Name or Email
    
    // Logic: Find by Email OR Name
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

// 3. ADMIN: Get Users (Filter: pending vs active)
router.get("/admin/users", authMiddleware(["admin"]), async (req, res) => {
  try {
    // If 'active', get approved users. Else get pending.
    const filter = req.query.type === 'active' ? { isApproved: true } : { isApproved: false };
    const users = await User.find(filter).select("-password");
    res.json({ users });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// 4. ADMIN: Approve User
router.post("/admin/approve", authMiddleware(["admin"]), async (req, res) => {
  try {
    const { userId } = req.body;
    await User.findByIdAndUpdate(userId, { isApproved: true });
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// 5. ADMIN: Delete User (Revoke Access)
router.post("/admin/delete", authMiddleware(["admin"]), async (req, res) => {
  try {
    const { userId } = req.body;
    if(req.user.id === userId) return res.status(400).json({ message: "Cannot delete yourself" });
    
    await User.findByIdAndDelete(userId);
    res.json({ success: true, message: "User Deleted" });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// 6. ADMIN: Assign Section to Staff (✅ NEW ROUTE)
// Usage: Updates the 'assignedSection' field in the User document
router.post("/admin/assign-section", authMiddleware(["admin"]), async (req, res) => {
  try {
    const { userId, section } = req.body;
    await User.findByIdAndUpdate(userId, { assignedSection: section });
    res.json({ success: true, message: `Staff assigned to ${section}` });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;