// FR-017a: the re-authentication fixture must never ship. Fails if the production bundle contains it.
import { readdirSync, readFileSync } from "node:fs";
import { join } from "node:path";

const dir = new URL("../dist/assets", import.meta.url).pathname;
const offenders = readdirSync(dir)
  .filter((f) => f.endsWith(".js"))
  .filter((f) => {
    const text = readFileSync(join(dir, f), "utf8");
    return text.includes("__fixtures__") || text.includes("Re-authentication fixture") || text.includes("fixture-apply");
  });
if (offenders.length) {
  console.error(`check-no-fixtures: fixture code found in ${offenders.join(", ")}`);
  process.exit(1);
}
console.log("check-no-fixtures: ok");
