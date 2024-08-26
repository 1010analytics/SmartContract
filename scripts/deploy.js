async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with the account:", deployer.address);

  const vrfCoordinator = "";
  const linkToken = "";
  const keyHash = "";
  const fee = ethers.utils.parseEther("0.1");
  const devWallet = "0xF418D4c3daf5a9A77c072DCe7c1a3f1996D55689";

  const TaxToken = await ethers.getContractFactory("TaxToken");
  const taxToken = await TaxToken.deploy(
    vrfCoordinator,
    linkToken,
    keyHash,
    fee,
    devWallet
  );

  await taxToken.deployed();
  console.log("TaxToken deployed to:", taxToken.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
