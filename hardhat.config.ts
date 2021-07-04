import { task } from "hardhat/config";
import "@nomiclabs/hardhat-waffle";
import { HardhatUserConfig } from "hardhat/config";
import "hardhat-typechain";


task("accounts", "Prints the list of accounts", async (args, hre) => {
  const accounts = await hre.ethers.getSigners();

  for (const account of accounts) {
    console.log(await account.address);
  }
});

const config: HardhatUserConfig = {
  solidity: "0.8.0",
  paths: {
    artifacts: "./src/artifacts",
    sources: "./src/contracts",
  },
  networks: {
    hardhat: {
      chainId: 1337,
    },
  },
};

export default config;
