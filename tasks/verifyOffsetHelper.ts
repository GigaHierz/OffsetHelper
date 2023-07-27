import { task } from "hardhat/config";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import paths, { poolAddresses } from "../utils/paths";

task("verify:offsetHelper", "Verifies the OffsetHelper")
  .addParam("address", "The OffsetHelper address")
  .setAction(
    async (taskArgs: { address: any }, hre: HardhatRuntimeEnvironment) => {
      const { address } = taskArgs;

      const pathsToUse = paths[hre.network.name];
      const poolAddressesToUse = poolAddresses[hre.network.name];

      await hre.run("verify:verify", {
        address: address,
        constructorArguments: [
          Object.values(poolAddressesToUse),
          Object.keys(pathsToUse),
          Object.values(pathsToUse),
        ],
      });
      console.log(`OffsetHelper verified on ${hre.network.name} to:`, address);
    }
  );

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: "0.8.9",
};
