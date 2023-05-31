import { DeployFunction } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import addresses, { routerAddresses } from "../utils/addresses";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const addressesToUse = addresses[hre.network.name];

  const { deployments, getNamedAccounts } = hre;
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();
  const dexRouterAddress = routerAddresses[hre.network.name]; // Ubeswap

  if (!deployer) {
    throw new Error("Missing deployer address");
  }

  await deploy("Swapper", {
    from: deployer,
    args: [
      Object.keys(addressesToUse),
      Object.values(addressesToUse),
      dexRouterAddress,
      hre.network.name === "celo" || hre.network.name === "alfajores"
        ? "mcUSD"
        : "USDC",
      hre.network.name === "celo" || hre.network.name === "alfajores"
        ? "cUSD"
        : "WMATIC",
    ],
    log: true,
    autoMine: true, // speed up deployment on local network (ganache, hardhat), no effect on live networks
  });
};
export default func;
