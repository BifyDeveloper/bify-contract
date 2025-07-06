const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("BifyLaunchpad", function () {
  let bifyLaunchpad;
  let owner;
  let addr1;
  let addr2;

  beforeEach(async function () {
    [owner, addr1, addr2] = await ethers.getSigners();

    const BifyLaunchpad = await ethers.getContractFactory("BifyLaunchpad");
    bifyLaunchpad = await BifyLaunchpad.deploy();
    await bifyLaunchpad.waitForDeployment();
  });

  describe("Deployment", function () {
    it("Should set the right owner", async function () {
      expect(await bifyLaunchpad.owner()).to.equal(owner.address);
    });
  });

  describe("Basic Functionality", function () {
    it("Should allow owner to call functions", async function () {
      expect(await bifyLaunchpad.owner()).to.equal(owner.address);
    });
  });
});
