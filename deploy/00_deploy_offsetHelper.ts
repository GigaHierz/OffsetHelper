import { DeployFunction } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import addresses from "../utils/addresses";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const addressesToUse = addresses[hre.network.name];

  const { deployments, getNamedAccounts } = hre;
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  console.log(hre.network.name);

  if (!deployer) {
    throw new Error("Missing deployer address");
  }

  const contract = await deploy("OffsetHelper", {
    from: deployer,
    args: [
      Object.keys(addressesToUse),
      Object.values(addressesToUse),
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
  console.log("Contract address:", contract.address);
};
export default func;
