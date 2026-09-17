/// Native database disk provider (Constitution I v2.1.0 gap, v1 dialect only). On v2 its figures are
/// checked against the official database-dir/info results; on v1 the Disk vital must come from it.
Class FlightDeck.Test.NativeDatabases Extends %UnitTest.TestCase
{

Method TestPrivilegeComesFromSpec()
{
	set requires = ##class(FlightDeck.Capability.Map).Requires("POST /v2/database-dir/info")
	do $$$AssertEquals(requires.%ToJSON(), "[""%Admin_Manage:U"",""%Admin_Operate:U""]")
	do $$$AssertTrue(##class(FlightDeck.Capability.Map).CurrentUserMay("POST /v2/database-dir/info"), "test user is an administrator")
}

Method TestPercentUsedRule()
{
	do $$$AssertEquals(##class(FlightDeck.Native.Databases).PercentUsed(100, 25, 200, 999), 37.5, "MaxSize bounds capacity")
	do $$$AssertEquals(##class(FlightDeck.Native.Databases).PercentUsed(100, 0, 0, 100), 50, "unlimited: Size + DiskFree")
}

/// Same figures as the official API, database by database (v2 only: v1 has no database-dir operations).
Method TestMatchesOfficialApi()
{
	if '##class(FlightDeck.Admin.Client).Has("POST /v2/database-dir/info") {
		do $$$LogMessage("skipped: the instance has no database-dir operations to compare with")
		quit
	}
	set sc = ##class(FlightDeck.Native.Databases).Usage(.rows)
	do $$$AssertStatusOK(sc)
	do $$$AssertTrue(rows.%Size() > 0)
	set compared = 0
	set iter = rows.%GetIterator()
	while iter.%GetNext(, .row) {
		do ##class(FlightDeck.Admin.Client).Call("POST", "/v2/database-dir/info", {"dir":(row.Directory)}, , .status, , , .headers)
		continue:status'=202
		set id = $piece($piece($get(headers("location")), "id=", 2), "&", 1)
		set api = ""
		for i=1:1:40 {
			do ##class(FlightDeck.Admin.Client).Call("GET", "/v2/async-result", {"id":(id)}, , .status, .json)
			if $isobject(json), $isobject(json.result.Result), json.result.Result.Size '= "" set api = json.result.Result quit
			hang 0.05
		}
		continue:'$isobject(api)
		set compared = compared + 1
		do $$$AssertEquals(row.Size, +api.Size, row.Name_" Size")
		do $$$AssertEquals(row.MaxSize, +api.MaxSize, row.Name_" MaxSize")
		// Free space moves while IRIS runs (IRISTEMP, IRISAUDIT): allow 1 MB.
		do $$$AssertTrue($zabs(row.AvailableSpace - api.AvailableSpace) <= 1, row.Name_" AvailableSpace "_row.AvailableSpace_" vs "_api.AvailableSpace)
		set apiDiskFree = ##class(FlightDeck.Vitals.Service).ToMB(api.DiskFree)
		do $$$AssertTrue($zabs(row.DiskFree - apiDiskFree) <= (apiDiskFree * 0.01 + 1), row.Name_" DiskFree "_row.DiskFree_" MB vs "_api.DiskFree)
	}
	do $$$AssertTrue(compared > 0, compared_" databases compared")
}

Method TestDiskVitalSourceFollowsInstance()
{
	set vital = ##class(FlightDeck.Vitals.Service).Disk()
	set native = '##class(FlightDeck.Admin.Client).Has("POST /v2/database-dir/info")
	do $$$AssertEquals(vital.source, $select(native:"native", 1:"api"))
	if native {
		do $$$AssertEquals(vital.state '= "unavailable", 1, "native disk vital has a value: "_vital.%ToJSON())
		do $$$AssertTrue((vital.value >= 0) && (vital.value <= 100), "value "_vital.value)
	}
}

/// The installer's native bootstrap lookup finds the same resource as the official operations.
Method TestCodeDatabaseResourceMatchesApi()
{
	set sc = ##class(FlightDeck.Native.Databases).CodeDatabaseResource($namespace, .nativeResource, .nativeDb)
	do $$$AssertStatusOK(sc)
	do $$$AssertTrue(nativeResource '= "", "resource "_nativeResource_" of "_nativeDb)
	if '##class(FlightDeck.Admin.Client).Has("GET /v2/namespace") {
		do $$$LogMessage("no namespace operations on this instance: native lookup only")
		quit
	}
	set ns = ##class(FlightDeck.Admin.Client).Get("/v2/namespace", {"name":($namespace)})
	set db = ##class(FlightDeck.Admin.Client).Get("/v2/database", {"name":(ns.Routines)})
	set dir = ##class(FlightDeck.Admin.Client).Get("/v2/database-dir", {"dir":(db.Directory)})
	do $$$AssertEquals(nativeDb, ns.Routines)
	do $$$AssertEquals(nativeResource, dir.ResourceName)
}

}
