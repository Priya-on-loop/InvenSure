require("@nomicfoundation/hardhat-toolbox");

// We load variables directly to keep things simple for deployment
const ALCHEMY_API_KEY = "https://eth-sepolia.g.alchemy.com/v2/nmLfzQU_uyGqwLax3rF2X";
const PRIVATE_KEY = "e2f12547eef7ef3d0df57f68e9c48c827c52cb0c8b5916a6c2d0f52fe666f49d";

module.exports = {
  solidity: "0.8.0",
  networks: {
    sepolia: {
      url: ALCHEMY_API_KEY,
      accounts: [PRIVATE_KEY],
    },
  },
};