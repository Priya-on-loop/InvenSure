const mongoose = require("mongoose");
const bcrypt = require("bcryptjs");

const userSchema = new mongoose.Schema({
  name: { type: String, required: true },
  email: { type: String, required: true, unique: true },
  password: { type: String, required: true },
  
  // Roles: Admin, Staff, Recycler
  role: { type: String, enum: ["admin", "staff", "recycler"], default: "staff" },
  
  // Security: Account Approval
  isApproved: { type: Boolean, default: false },

  // Assigned Section (For Row-Level Security in aisles)
  assignedSection: { type: String, default: "All" } 
});

// ✅ CORRECT: Using async/await WITHOUT 'next'
userSchema.pre("save", async function () {
  // If password is not modified, exit function
  if (!this.isModified("password")) return;
  
  // Hash the password
  this.password = await bcrypt.hash(this.password, 10);
});

// Method to verify password during login
userSchema.methods.comparePassword = async function (candidatePassword) {
  return await bcrypt.compare(candidatePassword, this.password);
};

const User = mongoose.model("User", userSchema);
module.exports = User;