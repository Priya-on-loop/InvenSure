const mongoose = require("mongoose");

const productSchema = new mongoose.Schema({
  // The Barcode or ID scanned
  id: { type: Number, required: true, unique: true }, 
  
  // Name of the product (e.g., "Milk")
  name: { type: String, required: true }, 
  
  // Expiry date stored as a number (timestamp) so we can compare dates easily
  expiry: { type: Number, required: true }, 
  
  // Tracks if the item has been recycled
  recycled: { type: Boolean, default: false },
});

const Product = mongoose.model("Product", productSchema);
module.exports = Product;