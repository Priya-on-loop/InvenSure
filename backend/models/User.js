const mongoose = require("mongoose");
const bcrypt = require("bcryptjs");

const userSchema = new mongoose.Schema({
  name: { type: String, required: true },
  email: { type: String, required: true, unique: true },
  password: { type: String, required: true },
  
  // Roles including recycler
  role: { type: String, enum: ["admin", "staff", "recycler"], default: "staff" },
  
  // Security: Login approval
  isApproved: { type: Boolean, default: false },

  // ✅ NEW: The specific section/aisle allowed for this staff
  // Default is 'All' so they see everything until restricted by Admin
  assignedSection: { type: String, default: "All" } 
});

// Hash password before saving
userSchema.pre("save", async function (next) {
  if (!this.isModified("password")) return next();
  this.password = await bcrypt.hash(this.password, 10);
  next();
});

// Method to verify password
userSchema.methods.comparePassword = async function (candidatePassword) {
  return await bcrypt.compare(candidatePassword, this.password);
};

const User = mongoose.model("User", userSchema);
module.exports = User;