const mongoose = require("mongoose");

const ProductSchema = new mongoose.Schema({
  // The Barcode or ID scanned
  id: { type: Number, required: true, unique: true }, 
  
  // Name of the product (e.g., "Milk")
  name: { type: String, required: true }, 
  
  // Expiry date stored as a number (timestamp)
  expiry: { type: Number, required: true }, 
  
  // Tracks if the item has been recycled (Blockchain sync flag)
  recycled: { type: Boolean, default: false },

  // Stores the product picture as a Base64 string
  image: { type: String, default: "" },

  // ✅ NEW: Workflow Fields for Recyclers
  // Links to the User who is assigned to recycle this
  assignedRecycler: { type: mongoose.Schema.Types.ObjectId, ref: 'User', default: null },
  
  // Tracks the current status of the recycling job
  recyclingStatus: { 
    type: String, 
    enum: ['none', 'assigned', 'completed'], 
    default: 'none' 
  },
  
  // When the admin assigned the task
  assignedDate: { type: Date }
});

module.exports = mongoose.model("Product", ProductSchema);