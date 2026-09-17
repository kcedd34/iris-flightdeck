import { NO_PRIVILEGE, OPERATOR, ensureUser } from "./users";

export default async function globalSetup() {
  await ensureUser(OPERATOR.user, OPERATOR.password, ["%Operator"]);
  await ensureUser(NO_PRIVILEGE.user, NO_PRIVILEGE.password, []);
}
