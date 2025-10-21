require('dotenv').config();
const hre = require('hardhat');

async function main() {
  const KipuBankV3 = await hre.ethers.getContractFactory("KipuBankV3");
  const kipuBank = await KipuBankV3.deploy(process.env.UNIVERSAL_ROUTER, process.env.PERMIT2);

  await kipuBank.deployed();

  console.log("KipuBankV3 deployed to:", kipuBank.address);

  // Verificación opcional en Etherscan
  await hre.run("verify:verify", {
    address: kipuBank.address,
    constructorArguments: [process.env.UNIVERSAL_ROUTER, process.env.PERMIT2],
  });
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
