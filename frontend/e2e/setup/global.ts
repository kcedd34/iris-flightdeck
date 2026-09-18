import { CHAIN, EXPIRED, NO_PRIVILEGE, OPERATOR, WALLET_ONLY, ensureRole, ensureUser } from "./users";

export default async function globalSetup() {
  await ensureUser(OPERATOR.user, OPERATOR.password, ["%Operator"]);
  await ensureUser(NO_PRIVILEGE.user, NO_PRIVILEGE.password, []);
  // Feature 003: the account that holds the demo role chain, the wallet-only administrator that
  // reaches partial mode (probe P5), and an account whose expiry is already past (probe P1).
  // Direct and inherited grants at once: FD_Demo_Operator grants a resource directly, FD_Demo_L1
  // only through two more roles, so provenance has both shapes to explain (US1 scenarios 1 and 2).
  await ensureUser(CHAIN.user, CHAIN.password, ["FD_Demo_L1", "FD_Demo_Operator"]);
  await ensureRole("FD_E2E_WalletAdmin", "FlightDeck e2e: wallet administration only", [{ Name: "%Admin_Wallet", Permissions: "U" }]);
  // %Operator comes with it because the official GET /info answers 404 for an account that holds
  // only %Admin_Wallet, although the wallet operations themselves answer 200 for it
  // (verification/README.md). The account still lacks %Admin_Secure, which is what makes the
  // impact and the last-administrator check report themselves incomplete.
  await ensureUser(WALLET_ONLY.user, WALLET_ONLY.password, ["FD_E2E_WalletAdmin", "%Operator"]);
  await ensureUser(EXPIRED.user, EXPIRED.password, ["%Manager"], { expirationDate: "2020-01-01" });
}
