import { deploy } from "./deployUtils";

deploy("ERC20Mock", ["100000", "MyToken", "MTK"]).catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
