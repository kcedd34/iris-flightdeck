import { execFileSync } from "node:child_process";
import { expect, test } from "@playwright/test";
import { signIn } from "./setup/helpers";
import { adminRequest } from "./setup/users";

// Feature 003, User Story 4 (PRD UC06-2 and spec scenarios 2 and 3): what expires, before it does.

const CONTAINER = process.env.FD_CONTAINER ?? "iris-flightdeck-iris-1";
const ALIAS = "FD_E2E_Expiring";
const DIR = "/tmp/fd-e2e-cert";

/** A self-signed certificate valid for a few days, generated inside the instance's container. */
function makeCertificate(days: number): boolean {
  try {
    execFileSync("docker", ["exec", CONTAINER, "sh", "-c", `mkdir -p ${DIR} && cd ${DIR} && openssl req -x509 -newkey rsa:2048 -keyout k.pem -out c.pem -days ${days} -nodes -subj "/CN=fd-e2e" >/dev/null 2>&1`], { stdio: ["ignore", "pipe", "ignore"] });
    return true;
  } catch {
    return false;
  }
}

test.beforeAll(async () => {
  if (!makeCertificate(5)) return;
  await adminRequest("DELETE", "/security/x509-credential", { alias: ALIAS });
  await adminRequest("POST", "/security/x509-credential", {}, { Alias: ALIAS, CertificateFile: `${DIR}/c.pem`, PrivateKeyFile: `${DIR}/k.pem`, OwnerList: [] });
});

test.afterAll(async () => {
  await adminRequest("DELETE", "/security/x509-credential", { alias: ALIAS });
  try {
    execFileSync("docker", ["exec", CONTAINER, "rm", "-rf", DIR], { stdio: "ignore" });
  } catch {
    // The cleanup needs the same Docker access the setup did; its absence already skipped the tests.
  }
});

test.beforeEach(async ({ page }) => {
  const credential = await adminRequest("GET", "/security/x509-credential", { alias: ALIAS });
  test.skip(credential.status !== 200, "docker or openssl is not available, so no expiring certificate could be created");
  await signIn(page);
});

test("2. A credential expiring inside the alert window shows its days and band in the list", async ({ page }) => {
  await page.goto("security/x509");
  const row = page.getByTestId("list-row").filter({ hasText: ALIAS });
  await expect(row.getByTestId("marker-expiring")).toContainText(/Expires in \d+ days/);
  // The band is not colour alone: the marker carries its text.
  await expect(row.getByTestId("marker-expiring")).toBeVisible();
});

test("PRD UC06-2. The same credential appears among the home panel's attention items, one click from its entity", async ({ page }) => {
  await page.goto("./");
  const attention = page.getByTestId("home-attention");
  await expect(attention).toContainText(ALIAS);
  await expect(attention.getByTestId("attention-expiring")).toContainText(/expires in \d+ days/);
  await attention.getByRole("link").filter({ hasText: ALIAS }).click();
  await expect(page.getByTestId("entity-inspector").getByRole("heading", { name: ALIAS })).toBeVisible();
});

test("3. An item whose validity the platform does not report says so, and is not counted as valid", async ({ page }) => {
  // A TLS configuration names a certificate file; the official API reports no validity for it.
  await page.goto("security/tls");
  const row = page.getByTestId("list-row").first();
  await expect(row.getByTestId("marker-validity-unknown")).toContainText("Validity not reported by the platform");
  await page.goto("./");
  await expect(page.getByTestId("home-attention")).not.toContainText("Validity not reported");
});

test("The certificate panel shows what the platform reports about the certificate", async ({ page }) => {
  // A single key that is not called "name" travels in the query form of the address.
  await page.goto(`security/x509?inspect=${encodeURIComponent(`security/x509-credential:?alias=${ALIAS}`)}`);
  const certificate = page.getByTestId("links-group-certificate");
  await expect(certificate).toContainText("CN=fd-e2e");
  await expect(certificate).toContainText(/days remaining/);
});
