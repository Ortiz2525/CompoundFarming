import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import * as dotenv from 'dotenv';

dotenv.config();

// Go to https://infura.io, sign up, create a new API key
// in its dashboard, and replace "KEY" with it
//const INFURA_API_KEY: string | undefined = process.env.INFURA_API_KEY;

// Replace this private key with your Sepolia account private key
// To export your private key from Metamask, open Metamask and
// go to Account Details > Export Private Key
// Beware: NEVER put real Ether into testing accounts
//const PRIVATE_KEY: string| undefined = process.env.WALLET_PRIVATE_KEY;
const { INFURA_API_KEY, PRIVATE_KEY, ETHERSCAN_API_KEY } = process.env;


const config: HardhatUserConfig = {
  solidity: "0.8.18",
  networks: {
    hardhat: {
        forking: {
          // url: "https://mainnet.infura.io/v3/9302aa8d88b44d37a7b45271ecaaeb25",
          url: "https://eth-mainnet.g.alchemy.com/v2/_6Ek2Lzp4UHqjrPb7cNAdRWZSJxiuEkv",
        },
      allowUnlimitedContractSize: true
    },
    localhost: {
      allowUnlimitedContractSize: true
    },
    mumbai: {
      url: `https://rpc-mumbai.maticvigil.com`, 
      accounts: [PRIVATE_KEY]
    }
    
  },
    etherscan: {
      apiKey: ETHERSCAN_API_KEY,
    },
};

export default config;