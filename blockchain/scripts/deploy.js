const hre = require("hardhat");

async function main() {
  const ExpiryTracker = await hre.ethers.getContractFactory("ExpiryTracker");
  const expiryTracker = await ExpiryTracker.deploy();

  await expiryTracker.waitForDeployment();

  console.log("ExpiryTracker deployed to:",await expiryTracker.getAddress());
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});