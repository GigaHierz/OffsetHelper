import { DeployFunction } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import paths, { poolAddresses } from "../utils/paths";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const pathsToUse = paths[hre.network.name];
  const poolAddressesToUse = poolAddresses[hre.network.name];

  const { deployments, getNamedAccounts } = hre;
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  if (!deployer) {
    throw new Error("Missing deployer address");
  }

  await deploy("OffsetHelper", {
    from: deployer,
    args: [
      Object.values(poolAddressesToUse),
      Object.keys(pathsToUse),
      Object.values(pathsToUse),
    ],
    log: true,
    autoMine: true, // speed up deployment on local network (ganache, hardhat), no effect on live networks
  });
};
export default func;
