import { execFileSync } from "node:child_process";

// Test-install switches that have no HTTP surface on purpose. They run ObjectScript in the
// container through docker exec (FD_CONTAINER, default the compose service of this repository).
const CONTAINER = process.env.FD_CONTAINER ?? "iris-flightdeck-iris-1";
const NAMESPACE = process.env.FD_NAMESPACE ?? "USER";

function run(code: string): void {
  execFileSync("docker", ["exec", "-i", CONTAINER, "iris", "session", "IRIS", "-U", NAMESPACE], { input: `${code}\nhalt\n`, encoding: "utf8" });
}

/**
 * Whether these switches can be used at all: the docker CLI is on PATH and the install's container
 * answers. A runner without Docker skips the tests that need them with a stated reason, instead of
 * failing as though the product were broken.
 */
export function dockerAvailable(): boolean {
  try {
    execFileSync("docker", ["exec", CONTAINER, "true"], { stdio: "ignore" });
    return true;
  } catch {
    return false;
  }
}

export const DOCKER_SKIP_REASON = `docker exec on ${CONTAINER} is not available from the test runner; the pattern catalog switch needs it (set FD_CONTAINER for another install)`;

/** Enables or disables the pattern catalog on the test install (feature 002 research R13). */
export function setFixtures(enabled: boolean): void {
  run(enabled ? 'set ^FlightDeck.Install("fixtures")=1' : 'kill ^FlightDeck.Install("fixtures")');
}
