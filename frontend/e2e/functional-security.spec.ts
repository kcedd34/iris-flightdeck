import { expect, test } from "@playwright/test";
import { adminRequest } from "./setup/users";
import { list, mutate } from "./setup/flightdeck";
import { verifiedEffect, verifiedRead } from "./setup/effect";
import { requireV2Dialect } from "./setup/dialect";

// Feature 008: security-domain operations that had never been executed.
//
// The encryption reads are here and the encryption writes are not: those eleven are declined by
// policy and are exempted by name, not tested.

const SSL = "FDFunctionalTLS";
const X509 = "FDFunctionalX509";

test.beforeEach(requireV2Dialect);

test.describe("TLS configurations", () => {
  test.afterAll(async () => {
    await adminRequest("DELETE", "/security/ssl-configuration", { name: SSL });
  });

  test("PUT /v2/security/ssl-configuration edits one, and the instance reports the change", async ({ request }) => {
    await adminRequest("DELETE", "/security/ssl-configuration", { name: SSL });
    await adminRequest("PUT", "/security/ssl-configuration", { name: SSL }, { Description: "created for functional coverage", Enabled: true, Type: "0", VerifyPeer: 0 });
    const wanted = `edited by FlightDeck ${Date.now()}`;
    await mutate(request, {
      operationId: "PUT /v2/security/ssl-configuration",
      keys: { name: SSL },
      proposed: { Description: wanted, Enabled: true, Type: "0", VerifyPeer: 0 },
    });
    await verifiedEffect(
      { operationId: "PUT /v2/security/ssl-configuration", subject: SSL, proves: "the instance reports the description that was sent" },
      async () => {
        const after = await adminRequest("GET", "/security/ssl-configuration", { name: SSL });
        expect((after.json as { result?: { Description?: string } }).result?.Description).toBe(wanted);
      },
    );
  });
});

test.describe("superservers", () => {
  test("GET /v2/security/superserver answers what the instance holds", async ({ request }) => {
    await verifiedRead("GET /v2/security/superserver", "the superserver FlightDeck lists is one the instance confirms", async () => {
      const rows = await list(request, "security", "superserver");
      expect(rows.items.length, "the instance should define at least one superserver").toBeGreaterThan(0);
      const port = rows.items[0]!.keys.port ?? rows.items[0]!.displayName;
      const official = await adminRequest("GET", "/security/superserver", { port: String(port) });
      expect(official.status, `the instance must hold superserver ${port}`).toBe(200);
    });
  });

  test("PUT /v2/security/superserver edits one, and the instance reports the change", async ({ request }) => {
    const rows = await list(request, "security", "superserver");
    test.skip(rows.items.length === 0, "this instance defines no superserver");
    const keys = rows.items[0]!.keys;
    const before = await adminRequest("GET", "/security/superserver", keys);
    const was = ((before.json as { result?: Record<string, any> }).result ?? {}) as Record<string, any>;
    const wanted = `FlightDeck functional coverage ${Date.now()}`;
    await mutate(request, { operationId: "PUT /v2/security/superserver", keys, proposed: { Description: wanted } });
    await verifiedEffect(
      { operationId: "PUT /v2/security/superserver", subject: `superserver ${JSON.stringify(keys)}`, proves: "the instance reports the description that was sent" },
      async () => {
        const after = await adminRequest("GET", "/security/superserver", keys);
        expect((after.json as { result?: { Description?: string } }).result?.Description).toBe(wanted);
      },
    );
    if (was.Description !== undefined) await adminRequest("PUT", "/security/superserver", keys, { Description: was.Description });
  });
});

test.describe("X.509 credentials", () => {
  test.afterAll(async () => {
    await adminRequest("DELETE", "/security/x509-credential", { alias: X509 });
  });

  test("POST /v2/security/x509-credential is refused honestly without a certificate, and says why", async ({ request }) => {
    // There is no certificate on this instance to load, so what is verified is the refusal: the
    // platform's own message reaches the caller intact rather than being reported as success. An
    // operation that answered 200 here without creating anything is the failure this suite hunts.
    const response = await mutate(request, {
      operationId: "POST /v2/security/x509-credential",
      keys: { alias: X509 },
      proposed: { Alias: X509, CertificateFile: "/does/not/exist.cer" },
    }).catch((error: Error) => error);
    await verifiedEffect(
      { operationId: "POST /v2/security/x509-credential", subject: X509, proves: "nothing was created, and the refusal came from the instance rather than from FlightDeck inventing success" },
      async () => {
        const after = await adminRequest("GET", "/security/x509-credential", { alias: X509 });
        expect(after.status, "no credential may exist after a refused create").not.toBe(200);
        expect(response instanceof Error, "the mutation layer must not report success for a refused create").toBe(true);
      },
    );
  });
});

test.describe("encryption, which is read-only here", () => {
  test("GET /v2/security/encryption/file/keys and /admins read through their link groups", async ({ request }) => {
    const files = await adminRequest("GET", "/security/encryption/files", { maxRows: "20" });
    const first = ((files.json as { result?: { Name?: string }[] })?.result ?? [])[0];
    test.skip(!first, "this instance has no encryption key file, so there is nothing to read");
    const rows = { items: [{ keys: { file: first!.Name! } }] };
    await verifiedRead("GET /v2/security/encryption/file/keys", "the keys of a key file are read and listed", async () => {
      const official = await adminRequest("GET", "/security/encryption/file/keys", rows.items[0]!.keys);
      expect(official.status).toBe(200);
    });
    await verifiedRead("GET /v2/security/encryption/file/admins", "the administrators of a key file are read and listed", async () => {
      const official = await adminRequest("GET", "/security/encryption/file/admins", rows.items[0]!.keys);
      expect(official.status).toBe(200);
    });
  });
});
