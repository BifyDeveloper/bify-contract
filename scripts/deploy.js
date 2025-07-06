const { ethers } = require("hardhat");

async function main() {
  const [deployer] = await ethers.getSigners();

  console.log("Deploying contracts with the account:", deployer.address);
  console.log(
    "Account balance:",
    (await ethers.provider.getBalance(deployer.address)).toString()
  );

  try {
    const BifyLaunchpad = await ethers.getContractFactory("BifyLaunchpad");
    const bifyLaunchpad = await BifyLaunchpad.deploy();
    await bifyLaunchpad.waitForDeployment();
    console.log("BifyLaunchpad deployed to:", await bifyLaunchpad.getAddress());

    const BifyMarketplace = await ethers.getContractFactory("BifyMarketplace");
    const bifyMarketplace = await BifyMarketplace.deploy();
    await bifyMarketplace.waitForDeployment();
    console.log(
      "BifyMarketplace deployed to:",
      await bifyMarketplace.getAddress()
    );

    const NFTCollection = await ethers.getContractFactory("NFTCollection");
    const nftCollection = await NFTCollection.deploy();
    await nftCollection.waitForDeployment();
    console.log("NFTCollection deployed to:", await nftCollection.getAddress());

    const BifyNFT = await ethers.getContractFactory("BifyNFT");
    const bifyNFT = await BifyNFT.deploy();
    await bifyNFT.waitForDeployment();
    console.log("BifyNFT deployed to:", await bifyNFT.getAddress());

    const WhitelistManagerExtended = await ethers.getContractFactory(
      "WhitelistManagerExtended"
    );
    const whitelistManager = await WhitelistManagerExtended.deploy();
    await whitelistManager.waitForDeployment();
    console.log(
      "WhitelistManagerExtended deployed to:",
      await whitelistManager.getAddress()
    );

    const BifyTokenPayment = await ethers.getContractFactory(
      "BifyTokenPayment"
    );
    const bifyTokenPayment = await BifyTokenPayment.deploy();
    await bifyTokenPayment.waitForDeployment();
    console.log(
      "BifyTokenPayment deployed to:",
      await bifyTokenPayment.getAddress()
    );

    console.log("\nDeployment completed successfully!");
    console.log("\nContract Addresses:");
    console.log("BifyLaunchpad:", await bifyLaunchpad.getAddress());
    console.log("BifyMarketplace:", await bifyMarketplace.getAddress());
    console.log("NFTCollection:", await nftCollection.getAddress());
    console.log("BifyNFT:", await bifyNFT.getAddress());
    console.log(
      "WhitelistManagerExtended:",
      await whitelistManager.getAddress()
    );
    console.log("BifyTokenPayment:", await bifyTokenPayment.getAddress());
  } catch (error) {
    console.error("Deployment failed:", error);
    process.exit(1);
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
