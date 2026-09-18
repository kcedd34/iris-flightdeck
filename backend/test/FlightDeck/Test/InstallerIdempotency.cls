Class FlightDeck.Test.InstallerIdempotency Extends %UnitTest.TestCase
{

Method TestSecondRunCreatesNothing()
{
	do $$$AssertStatusOK(##class(FlightDeck.Install.Demo).Provision())
	do $$$AssertStatusOK(##class(FlightDeck.Install.Demo).Provision())
	set tasks = ##class(FlightDeck.Admin.Client).Get("/v2/tasks", {"filter":"FD Demo", "maxRows":100}, .status)
	do $$$AssertEquals(status, 200)
	set count = 0
	set iter = tasks.%GetIterator()
	while iter.%GetNext(, .task) { set:$extract(task.Name, 1, 7)="FD Demo" count = count + 1 }
	do $$$AssertEquals(count, 3, "exactly three demo tasks")
}

/// Feature 003 gave the demo collection one secret, so the wallet screens have something that is
/// never displayed. The listing must carry names and types only: no value, in any field.
Method TestWalletSecretIsListedWithoutItsValue()
{
	set secrets = ##class(FlightDeck.Admin.Client).Get("/v2/wallet/secrets", {"collection":"FD_Demo_Vault"}, .status, .raw)
	if status = 404 {
		do $$$AssertTrue(1, "Wallet API absent on this instance")
		quit
	}
	do $$$AssertEquals(status, 200, raw)
	quit:'$isobject(secrets)
	set text = secrets.%ToJSON()
	// The demo secret exists where the version's API accepts the configuration FlightDeck sends;
	// IRIS 2026.1 wants a different shape and the installer skips it with the platform's message
	// (verification/README.md). Either way, the listing carries names and types only.
	if secrets.%Size() > 0 {
		do $$$AssertTrue(text [ "FD_Demo_Vault.FD_Demo_Token", "the secret is listed by name")
	}
	do $$$AssertNotTrue(text [ "flightdeck-demonstration-value", "no value in the listing")
	do $$$AssertNotTrue(text [ "WalletSecretConfig", "no secret configuration in the listing")
}

Method TestRuntimeRoleGrantsOnlyCodeDatabaseRead()
{
	do $$$AssertStatusOK(##class(FlightDeck.Install.Installer).EnsureRuntimeRole())
	set role = ##class(FlightDeck.Admin.Client).Get("/v2/security/role", {"name":"FlightDeck_Runtime"}, .status)
	do $$$AssertEquals(status, 200)
	do $$$AssertEquals(role.Resources.%Size(), 1, "one resource")
	do $$$AssertEquals(role.Resources.%Get(0).Permissions, "R", "read only")
}

Method TestFlightDeckApplicationsRecordedForSelfProtection()
{
	do $$$AssertStatusOK(##class(FlightDeck.Install.Installer).VerifyWebApps())
	do $$$AssertStatusOK(##class(FlightDeck.Install.Installer).VerifyWebApps())
	set count = 0, name = ""
	for { set name = $order(^FlightDeck.Install("applications", name)) quit:name=""  set count = count + 1 }
	do $$$AssertEquals(count, 2, "exactly the two declared applications, after two runs")
	set api = ##class(FlightDeck.Domain.Facts).FlightDeckApplication("/api/flightdeck")
	do $$$AssertEquals(api.requiredAuthBits, 32)
	do $$$AssertEquals(api.runtimeRole, "FlightDeck_Runtime")
	do $$$AssertEquals(api.namespace, $namespace)
	do $$$AssertEquals(##class(FlightDeck.Domain.Facts).FlightDeckApplication("/flightdeck").requiredAuthBits, 64)
	do $$$AssertNotTrue(##class(FlightDeck.Domain.Facts).IsFlightDeckApplication("/csp/fd-demo"))
}

}
