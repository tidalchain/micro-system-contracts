import "@zkamoeba/hardhat-micro-chai-matchers";
import "@zkamoeba/hardhat-micro-solc";
import "@nomiclabs/hardhat-ethers";
import "@nomiclabs/hardhat-solpp";
import "@typechain/hardhat";
import "@zkamoeba/hardhat-micro-verify";

// eslint-disable-next-line @typescript-eslint/no-var-requires
const systemConfig = require("./SystemConfig.json");

export default {
  zksolc: {
    version: "1.3.14",
    compilerSource: "binary",
    settings: {
      isSystem: true,
    },
  },
  microDeploy: {
    microNetwork: "http://localhost:3050",
    fileNetwork: "http://localhost:1234/rpc/v1",
  },
  solidity: {
    version: "0.8.20",
    settings: {
      optimizer: {
        enabled: true,
        runs: 9999999,
      },
      outputSelection: {
        "*": {
          "*": ["storageLayout"],
        },
      },
    },
  },
  solpp: {
    defs: (() => {
      return {
        ECRECOVER_COST_GAS: systemConfig.ECRECOVER_COST_GAS,
        KECCAK_ROUND_COST_GAS: systemConfig.KECCAK_ROUND_COST_GAS,
        SHA256_ROUND_COST_GAS: systemConfig.SHA256_ROUND_COST_GAS,
      };
    })(),
  },
  defaultNetwork: "microTestnet",
  networks: {
    hardhat: {
      micro: true,
    },
    microTestnet: {
      url: "http://127.0.0.1:3050",
      fileNetwork: "https://sepolia.infura.io/v3/25fba67f3fc14709a3d0b547fab88974",
      verifyURL: "http://127.0.0.1:3070/contract_verification",
      micro: true,
    },
  },
};
