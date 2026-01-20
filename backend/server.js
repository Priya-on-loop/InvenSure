require("dotenv").config();
const express = require("express");
const mongoose = require("mongoose");
const cors = require("cors");

// Initialize App
const app = express();

// --- MIDDLEWARE ---
app.use(express.json()); // Allows backend to read JSON data
app.use(cors());         // Allows frontend to communicate with backend

// --- DATABASE CONNECTION ---
mongoose
  .connect(process.env.MONGO_URI)
  .then(() => console.log(" MongoDB Connected"))
  .catch((err) => console.log(" DB Error:", err));

// --- ROUTES ---

// 1. Auth Routes (Login & Register)
// This matches your frontend calls to "/login" and "/register"
app.use("/", require("./routes/auth"));

// 2. Product Routes (Add, Get, Recycle - WITH BLOCKCHAIN)
// This matches your frontend calls to "/addProduct", "/allProducts", "/recycleProduct/:id"
app.use("/", require("./routes/products"));

// --- START SERVER ---
const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log(` Server running on port ${PORT}`));