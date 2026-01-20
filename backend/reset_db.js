// File: backend/reset_db.js
require('dotenv').config();
const mongoose = require('mongoose');

mongoose.connect(process.env.MONGO_URI)
  .then(async () => {
    console.log("🔌 Connected to DB...");
    try {
      // This deletes the 'users' collection and its bad indexes
      await mongoose.connection.collection('users').drop();
      console.log("✅SUCCESS: 'Users' collection dropped. The duplicate key error is gone.");
    } catch (err) {
      if (err.code === 26) {
        console.log("ℹ Collection users didn't exist, so nothing to do.");
      } else {
        console.error(" Error dropping collection:", err);
      }
    }
    process.exit(0);
  })
  .catch(err => {
    console.error("DB Connection Error:", err);
    process.exit(1);
  });