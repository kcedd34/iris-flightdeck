#!/usr/bin/env bash
# Provisions the demo instance after it is up (feature 007, items 5 to 7).
#
# Three accounts, deliberately distinct:
#   _SYSTEM      the instance's own administrative account. Its password on this VM is strong, set
#                from the environment, and exists nowhere in the repository. It is NOT published.
#   the demo     what visitors sign in with. Published on the sign-in form and in the README, and
#                holding %All, because permissions and security are the product's central argument:
#                impact analysis, the last-administrator predicate and the dry-run with provenance
#                are exactly what a reduced account would hide. Recovery replaces restriction here —
#                the watchdog and the hourly rebuild are what make that safe.
#   the reduced  the same portal seen by an account that holds %Operator and nothing else. It exists
#                because the capability map is invisible to an administrator who holds everything:
#                with %All nothing is ever disabled, so the one feature that decides what each
#                control may do cannot be seen at all. With %Operator, 57 of 273 operations are
#                offered and the rest are disabled naming the privilege they need, with Permissions
#                and Web applications closed outright. Published the same way, and rebuilt with the
#                rest of the instance every hour.
set -euo pipefail
CONTAINER="${FD_DEMO_CONTAINER:-flightdeck-demo}"

: "${FD_DEMO_USER:?}"
: "${FD_DEMO_PASSWORD:?}"
: "${FD_SYSTEM_PASSWORD:?}"
: "${FD_DEMO_REDUCED_USER:?}"
: "${FD_DEMO_REDUCED_PASSWORD:?}"

docker exec -i -e U="$FD_DEMO_USER" -e P="$FD_DEMO_PASSWORD" -e S="$FD_SYSTEM_PASSWORD" \
  -e LU="$FD_DEMO_REDUCED_USER" -e LP="$FD_DEMO_REDUCED_PASSWORD" \
  "$CONTAINER" iris session iris -U %SYS <<'OS' 2>&1 | grep -E '^provision:'
set user = $system.Util.GetEnviron("U"), password = $system.Util.GetEnviron("P"), system = $system.Util.GetEnviron("S")
// No $$$ macros here: this runs in a terminal session, where they are not defined. Status is read
// through $system.Status instead, which is available everywhere.
kill properties
set properties("Password") = password, properties("Roles") = "%All", properties("Enabled") = 1
set properties("ChangePassword") = 0, properties("ExpirationDate") = "", properties("FullName") = "FlightDeck public demo"
if ##class(Security.Users).Exists(user) {
  set sc = ##class(Security.Users).Modify(user, .properties)
} else {
  set sc = ##class(Security.Users).Create(user, "%All", password, "FlightDeck public demo")
  if $system.Status.IsOK(sc) set sc = ##class(Security.Users).Modify(user, .properties)
}
write !, "provision: demo account ", user, " ", $select($system.Status.IsOK(sc):"ok", 1:$system.Status.GetErrorText(sc))
// The reduced account. %Operator is a stock IRIS role, so nothing is invented here: what the
// visitor sees is what that role really grants on this platform, and the refusals come from the
// instance rather than from FlightDeck.
set account = $system.Util.GetEnviron("LU"), accountPassword = $system.Util.GetEnviron("LP")
kill reduced
set reduced("Password") = accountPassword, reduced("Roles") = "%Operator", reduced("Enabled") = 1
set reduced("ChangePassword") = 0, reduced("ExpirationDate") = "", reduced("FullName") = "FlightDeck public demo, reduced privileges"
if ##class(Security.Users).Exists(account) {
  set scl = ##class(Security.Users).Modify(account, .reduced)
} else {
  set scl = ##class(Security.Users).Create(account, "%Operator", accountPassword, "FlightDeck public demo, reduced privileges")
  if $system.Status.IsOK(scl) set scl = ##class(Security.Users).Modify(account, .reduced)
}
write !, "provision: reduced account ", account, " ", $select($system.Status.IsOK(scl):"ok", 1:$system.Status.GetErrorText(scl))

kill own
set own("Password") = system, own("ChangePassword") = 0
set sc2 = ##class(Security.Users).Modify("_SYSTEM", .own)
write !, "provision: _SYSTEM ", $select($system.Status.IsOK(sc2):"password changed", 1:$system.Status.GetErrorText(sc2))
halt
OS
echo "provision: done"
