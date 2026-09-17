import { execFileSync } from "node:child_process";

// Test-install switches that have no HTTP surface on purpose. They run ObjectScript in the
// container through docker exec (FD_CONTAINER, default the compose service of this repository).
const CONTAINER = process.env.FD_CONTAINER ?? "iris-flightdeck-iris-1";
const NAMESPACE = process.env.FD_NAMESPACE ?? "USER";

function run(code: string): void {
  execFileSync("docker", ["exec", "-i", CONTAINER, "iris", "session", "IRIS", "-U", NAMESPACE], { input: `${code}\nhalt\n`, encoding: "utf8" });
}

/** Enables or disables the pattern catalog on the test install (feature 002 research R13). */
export function setFixtures(enabled: boolean): void {
  run(enabled ? 'set ^FlightDeck.Install("fixtures")=1' : 'kill ^FlightDeck.Install("fixtures")');
}
