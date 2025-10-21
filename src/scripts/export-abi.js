// scripts/export-abi.js
import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";

// Para obtener __dirname en ESM
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Ruta del artifact generado por Hardhat
const artifactPath = path.join(__dirname, "../artifacts/contracts/KipuBankV3.sol/KipuBankV3.json");
const artifact = JSON.parse(fs.readFileSync(artifactPath, "utf-8"));

// Guardar ABI en un archivo separado (legible)
fs.writeFileSync("KipuBankV3-ABI.json", JSON.stringify(artifact.abi, null, 2));

// Guardar ABI en una línea (para Etherscan)
fs.writeFileSync("KipuBankV3-ABI-OneLine.json", JSON.stringify(artifact.abi));

console.log("ABI exportada a KipuBankV3-ABI.json y KipuBankV3-ABI-OneLine.json");
