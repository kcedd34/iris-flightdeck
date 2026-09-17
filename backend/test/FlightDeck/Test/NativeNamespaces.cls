/// Native namespace reads (Constitution I v2.1.0 gap, v1 dialect only). On IRIS 2026.2 every native
/// answer is compared with the official /v2/namespace operation for the same request; on the v1
/// dialect the same requests must reach the native provider through FlightDeck.Admin.Client.
Class FlightDeck.Test.NativeNamespaces Extends %UnitTest.TestCase
{

/// operationId|query JSON. Covers list, filter, maxRows, item, not found, missing parameters,
/// the three mapping kinds (list, names, item, unknown namespace).
Method Requests() As %List
{
	quit $listbuild(
		"GET /v2/namespaces|{}",
		"GET /v2/namespaces|{""filter"":""US""}",
		"GET /v2/namespaces|{""maxRows"":1}",
		"GET /v2/namespace|{""name"":""USER""}",
		"GET /v2/namespace|{""name"":""%SYS""}",
		"GET /v2/namespace|{""name"":""FDT_NOPE""}",
		"GET /v2/namespace|{}",
		"GET /v2/namespace/global-mappings|{""namespace"":""USER""}",
		"GET /v2/namespace/global-mappings|{""namespace"":""USER"",""names"":""EnsEDI*""}",
		"GET /v2/namespace/global-mappings|{""namespace"":""FDT_NOPE""}",
		"GET /v2/namespace/global-mappings|{}",
		"GET /v2/namespace/global-mapping|{""namespace"":""USER"",""name"":""EnsEDI.Schema""}",
		"GET /v2/namespace/global-mapping|{""namespace"":""USER"",""name"":""FDT_NOPE""}",
		"GET /v2/namespace/global-mapping|{""namespace"":""USER""}",
		"GET /v2/namespace/package-mappings|{""namespace"":""USER""}",
		"GET /v2/namespace/package-mappings|{""namespace"":""USER"",""maxRows"":2}",
		"GET /v2/namespace/package-mapping|{""namespace"":""USER"",""name"":""EnsLib""}",
		"GET /v2/namespace/package-mapping|{""namespace"":""USER"",""name"":""FDT_NOPE""}",
		"GET /v2/namespace/routine-mappings|{""namespace"":""USER""}",
		"GET /v2/namespace/routine-mapping|{""namespace"":""USER"",""name"":""Ens*""}",
		"GET /v2/namespace/routine-mapping|{""name"":""Ens*""}")
}

/// The comparable part of an answer: status, result, and each error's text, code and params.
Method Comparable(status As %Integer, json As %DynamicObject) As %String
{
	set errors = []
	if $isobject(json), $isobject(json.status) {
		set iter = json.status.errors.%GetIterator()
		while iter.%GetNext(, .e) { do errors.%Push({"error":(e.error), "code":(e.code), "params":(e.params)}) }
	}
	quit status _ " " _ $select($isobject(json):json.result.%ToJSON(), 1:"") _ " " _ errors.%ToJSON()
}

Method TestMatchesOfficialApi()
{
	if ##class(FlightDeck.Admin.Client).Limited() {
		do $$$LogMessage("skipped: no official namespace operations to compare with on the v1 dialect")
		quit
	}
	set ptr = 0, compared = 0
	while $listnext(..Requests(), ptr, request) {
		set operationId = $piece(request, "|", 1), query = ##class(%DynamicObject).%FromJSON($piece(request, "|", 2))
		do ##class(FlightDeck.Admin.Client).Call($piece(operationId, " ", 1), $piece(operationId, " ", 2), query, , .officialStatus, .official)
		do ##class(FlightDeck.Native.Namespaces).Handle(operationId, query, .nativeStatus, .native)
		do $$$AssertEquals(..Comparable(nativeStatus, native), ..Comparable(officialStatus, official), request)
		set compared = compared + 1
	}
	do $$$AssertEquals(compared, 21)
}

/// Runs in a job signed in as another user and records the provider's answer in IRISTEMP (the
/// fixture user may only read the FlightDeck code database).
ClassMethod AnswerAs(user As %String, password As %String, key As %String)
{
	set sc = $system.Security.Login(user, password)
	if $$$ISERR(sc) set ^IRIS.Temp.FlightDeckTest(key) = "login failed: "_$system.Status.GetErrorText(sc) quit
	set ^IRIS.Temp.FlightDeckTest(key) = "handle failed"
	do ##class(FlightDeck.Native.Namespaces).Handle("GET /v2/namespaces", {}, .status, .json)
	set ^IRIS.Temp.FlightDeckTest(key) = status _ " " _ json.status.errors.%Size() _ " " _ json.result.%ToJSON()
}

/// The provider itself refuses a user without the declared privilege (%Admin_Manage:U), like the API:
/// 403, no errors, empty result. The fixture user holds %Operator (not %Admin_Manage) and
/// FlightDeck_Runtime, which only grants read on the code database so the job can load the provider.
Method TestRefusesWithoutDeclaredPrivilege()
{
	set user = "fdt_no_manage", password = "Fdt-NoManage-2026"
	do ##class(FlightDeck.Admin.Client).Call("DELETE", "/v2/security/user", {"name":(user)})
	set st = ##class(FlightDeck.Admin.Client).Call("POST", "/v2/security/user", {"name":(user)}, {"Password":(password), "User":{"Enabled":true, "ChangePassword":false, "Roles":["%Operator", "FlightDeck_Runtime"]}}, .status, , .raw)
	do $$$AssertEquals(status, 201, "fixture user: "_raw)
	set key = $job _ "-" _ $zhorolog
	kill ^IRIS.Temp.FlightDeckTest(key)
	job ##class(FlightDeck.Test.NativeNamespaces).AnswerAs(user, password, key)
	set answer = ""
	for i=1:1:50 { set answer = $get(^IRIS.Temp.FlightDeckTest(key)) quit:(answer'="")&&(answer'["failed")  hang 0.1 }
	kill ^IRIS.Temp.FlightDeckTest(key)
	do ##class(FlightDeck.Admin.Client).Call("DELETE", "/v2/security/user", {"name":(user)})
	do $$$AssertEquals(answer, "403 0 {}", "provider answer for a %Operator user")
}

Method TestUnknownOperationIsNotAnswered()
{
	do ##class(FlightDeck.Native.Namespaces).Handle("PUT /v2/namespace", {"name":"FDT_NOPE"}, .status, .json)
	do $$$AssertEquals(status, 501, "writes are never native")
}

/// On v1 the client reaches the provider: available in the map, a list with USER and %SYS.
Method TestReachedThroughClientOnV1()
{
	if '##class(FlightDeck.Admin.Client).Limited() {
		do $$$LogMessage("skipped: the official operations answer on v2")
		quit
	}
	do $$$AssertTrue(##class(FlightDeck.Admin.Client).Has("GET /v2/namespaces"))
	set list = ##class(FlightDeck.Admin.Client).Get("/v2/namespaces", , .status)
	do $$$AssertEquals(status, 200)
	set names = ""
	set iter = list.%GetIterator()
	while iter.%GetNext(, .row) { set names = names _ "," _ row.Name }
	do $$$AssertTrue((names [ ",USER") && (names [ ",%SYS"), "namespaces"_names)
	set user = ##class(FlightDeck.Admin.Client).Get("/v2/namespace", {"name":"USER"}, .status)
	do $$$AssertEquals(status, 200)
	do $$$AssertEquals(user.Routines, "USER")
	do ##class(FlightDeck.Admin.Client).Call("PUT", "/v2/namespace", {"name":"FDT_NOPE"}, {"Globals":"USER", "Routines":"USER"}, .status, .json)
	do $$$AssertEquals(status, 501, "namespace writes stay unavailable")
	do $$$AssertTrue(json.status.errors.%Get(0).error [ "side effects", json.status.errors.%Get(0).error)
}

}
