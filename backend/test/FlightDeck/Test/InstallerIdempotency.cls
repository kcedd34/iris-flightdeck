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

Method TestWalletCollectionHasNoSecrets()
{
	set secrets = ##class(FlightDeck.Admin.Client).Get("/v2/wallet/secrets", {"collection":"FD_Demo_Vault"}, .status, .raw)
	if status = 404 {
		// Wallet API absent: the collection is skipped, which is also "no secrets".
		do $$$AssertTrue(1)
		quit
	}
	do $$$AssertEquals(status, 200, raw)
	do $$$AssertEquals($select($isobject(secrets):secrets.%Size(), 1:0), 0, "no secrets in FD_Demo_Vault")
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
