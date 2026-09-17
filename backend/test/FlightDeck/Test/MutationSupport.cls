/// Shared helpers for the mutation layer tests (feature 002): a disposable web application and
/// preview/apply calls through FlightDeck.Mutation.Service, the only write path.
Class FlightDeck.Test.MutationSupport Extends %UnitTest.TestCase [ Abstract ]
{

Parameter APP = "/csp/fdt-mutation";

Method OnBeforeAllTests() As %Status
{
	do ##class(FlightDeck.Admin.Client).Call("DELETE", "/v2/web-app", {"name":(..#APP)})
	do ##class(FlightDeck.Admin.Client).Call("PUT", "/v2/web-app", {"name":(..#APP)}, {"NameSpace":"USER", "Description":"FlightDeck test application", "Enabled":true, "AutheEnabled":32}, .status)
	quit $select(status=201:$$$OK, 1:$$$ERROR($$$GeneralError, "fixture application: HTTP "_status))
}

Method OnAfterAllTests() As %Status
{
	do ##class(FlightDeck.Admin.Client).Call("DELETE", "/v2/web-app", {"name":(..#APP)})
	quit $$$OK
}

Method Preview(operationId As %String, name As %String, proposed As %DynamicObject = "", Output status As %Integer) As %DynamicObject
{
	set request = {"operationId":(operationId), "keys":{"name":(name)}}
	if $isobject(proposed) set request.proposed = proposed
	quit ##class(FlightDeck.Mutation.Service).DoPreview(request, .status)
}

Method Apply(operationId As %String, name As %String, proposed As %DynamicObject = "", fingerprint As %String = "", confirmation As %String = "", acknowledged As %Boolean = 0, Output status As %Integer) As %DynamicObject
{
	set request = {"operationId":(operationId), "keys":{"name":(name)}, "fingerprint":(fingerprint), "confirmation":(confirmation)}
	do request.%Set("acknowledged", acknowledged, "boolean")
	if $isobject(proposed) set request.proposed = proposed
	quit ##class(FlightDeck.Mutation.Service).DoApply(request, .status)
}

Method Official(name As %String) As %DynamicObject
{
	quit ##class(FlightDeck.Admin.Client).Get("/v2/web-app", {"name":(name)})
}

}
