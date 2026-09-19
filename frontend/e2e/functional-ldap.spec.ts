import { expect, test } from "@playwright/test";
import { adminRequest } from "./setup/users";
import { mutate } from "./setup/flightdeck";
import { verifiedEffect } from "./setup/effect";
import { requireV2Dialect } from "./setup/dialect";

// Feature 008, step 5: LDAP.
//
// Of the four LDAP operations, three need no directory server at all — a configuration is stored on
// the instance whether or not anything answers at the other end, and its search password is written
// the same way every other secret is. Those three are exercised here, against a configuration this
// test creates and removes.
//
// The fourth, POST /v2/security/ldap/test, authenticates against the directory, and it is exempted by
// name. Standing up an OpenLDAP container would prove that IRIS can reach a container on the same
// docker network; it would not prove anything about a directory a user would actually point this at,
// and building infrastructure in order to be able to say something was tested is worth less than an
// exemption that says plainly what was not.

const NAME = "FDFunctionalLDAP";

test.beforeEach(requireV2Dialect);

test.describe("LDAP configurations", () => {
  test.afterAll(async () => {
    await adminRequest("DELETE", "/security/ldap/configuration", { name: NAME });
  });

  test("PUT /v2/security/ldap/configuration stores one the instance then reports", async ({ request }) => {
    await adminRequest("DELETE", "/security/ldap/configuration", { name: NAME });
    await mutate(request, {
      operationId: "PUT /v2/security/ldap/configuration",
      keys: { name: NAME },
      proposed: {
        Description: "FlightDeck functional coverage",
        LDAPHostNames: ["ldap.example.invalid"],
        LDAPBaseDN: "dc=example,dc=invalid",
        LDAPBaseDNForGroups: "ou=groups,dc=example,dc=invalid",
        LDAPSearchUsername: "cn=search,dc=example,dc=invalid",
      },
    });
    await verifiedEffect(
      { operationId: "PUT /v2/security/ldap/configuration", subject: NAME, proves: "the instance holds the configuration with the host and base DN that were sent" },
      async () => {
        const after = await adminRequest("GET", "/security/ldap/configuration", { name: NAME });
        expect(after.status, "the configuration must exist after FlightDeck created it").toBe(200);
        const body = ((after.json as { result?: Record<string, unknown> }).result ?? {}) as Record<string, unknown>;
        expect(String(body.LDAPHostNames)).toContain("ldap.example.invalid");
        expect(String(body.LDAPBaseDN)).toBe("dc=example,dc=invalid");
      },
    );
  });

  test("POST /v2/security/ldap/configuration/search-password sets a secret that never reads back", async ({ request }) => {
    const exists = await adminRequest("GET", "/security/ldap/configuration", { name: NAME });
    test.skip(exists.status !== 200, "the configuration test must run first");
    await mutate(request, {
      operationId: "POST /v2/security/ldap/configuration/search-password",
      keys: { name: NAME },
      // An action takes its name as a parameter, not as a key.
      params: { name: NAME, searchPassword: "Fd-Functional-LDAP-2026" },
      proposed: { Password: "Fd-Functional-LDAP-2026" },
    });
    await verifiedEffect(
      { operationId: "POST /v2/security/ldap/configuration/search-password", subject: NAME, proves: "the configuration still stands after the write, and the password is nowhere in what the instance returns" },
      async () => {
        const after = await adminRequest("GET", "/security/ldap/configuration", { name: NAME });
        expect(after.status).toBe(200);
        // Constitution VI: a secret is write-only. The effect that can be verified is the absence.
        expect(JSON.stringify(after.json)).not.toContain("Fd-Functional-LDAP-2026");
      },
    );
  });

  test("DELETE /v2/security/ldap/configuration removes it, and the instance stops holding it", async ({ request }) => {
    const exists = await adminRequest("GET", "/security/ldap/configuration", { name: NAME });
    test.skip(exists.status !== 200, "the configuration test must run first");
    await mutate(request, { operationId: "DELETE /v2/security/ldap/configuration", keys: { name: NAME } });
    await verifiedEffect(
      { operationId: "DELETE /v2/security/ldap/configuration", subject: NAME, proves: "the instance no longer holds the configuration" },
      async () => {
        const after = await adminRequest("GET", "/security/ldap/configuration", { name: NAME });
        expect(after.status, "the configuration is still there after it was deleted").not.toBe(200);
      },
    );
  });
});
