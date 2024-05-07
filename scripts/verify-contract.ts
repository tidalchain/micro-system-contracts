import "@zkamoeba/hardhat-micro-verify/dist/src/type-extensions";
import * as hre from "hardhat";
import { ethers } from "ethers";

async function main() {
  let contractName = "";
  let deployParam: any[] = [];
  let contractAddress = "";

  const artifact = hre.artifacts.readArtifactSync(contractName);
  const contractInterface = new ethers.utils.Interface(artifact.abi);

  // // Show the contract info.
  const fullContractSource = `${artifact.sourceName}:${artifact.contractName}`;
  const constructorArgs = contractInterface.encodeDeploy(deployParam);

  await verifyContract({
    address: contractAddress,
    contract: fullContractSource,
    constructorArguments: constructorArgs,
    bytecode: artifact.bytecode,
  });
}

const verifyContract = async (data: {
  address: string;
  contract: string;
  constructorArguments: string;
  bytecode: string;
}) => {
  console.log(hre);
  const verificationRequestId: number = await hre.run("verify:verify", {
    ...data,
    noCompile: true,
  });
  return verificationRequestId;
};

main();
