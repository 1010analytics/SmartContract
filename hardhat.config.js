require("@nomiclabs/hardhat-ethers");

module.exports = {
  defaultNetwork: "base",
  networks: {
    base: {
      url: "",
      accounts: [],
    },
  },
  solidity: {
    version: "0.8.0",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  vrf: {
    coordinator: "",
    linkToken: "",
    keyHash: "",
    fee: ethers.utils.parseEther("0.1"),
  },
};
