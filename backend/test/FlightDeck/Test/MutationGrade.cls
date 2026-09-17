/// Confirmation grades (feature 002 T037, research R5, RN-FD-04): decided by the operation and the
/// proposed change, never by the domain.
Class FlightDeck.Test.MutationGrade Extends FlightDeck.Test.MutationSupport
{

Method TestEditGrades()
{
	do $$$AssertEquals(..Preview("PUT /v2/web-app", ..#APP, {"Description":"x"}).grade, "simple", "description edit")
	for change = {"Enabled":false}, {"AutheEnabled":64}, {"Resource":"%Development"}, {"MatchRoles":[{"MatchRole":"", "TargetRoles":["%Developer"]}]}, {"NameSpace":"%SYS"}, {"DispatchClass":"FlightDeck.API.Router"} {
		set preview = ..Preview("PUT /v2/web-app", ..#APP, change)
		do $$$AssertEquals(preview.grade, "reinforced", change.%ToJSON())
		do $$$AssertEquals(preview.confirmText, ..#APP)
	}
	do $$$AssertEquals(..Preview("PUT /v2/web-app", "/api/flightdeck", {"Description":"x"}).grade, "reinforced", "any edit to a FlightDeck application")
}

Method TestCreateIsSimple()
{
	set preview = ..Preview("PUT /v2/web-app", "/csp/fdt-not-there", {"NameSpace":"USER"})
	do $$$AssertEquals(preview.kind, "create")
	do $$$AssertEquals(preview.grade, "simple")
	do $$$AssertEquals(preview.fingerprint, "absent")
}

Method TestDeleteGrades()
{
	set preview = ..Preview("DELETE /v2/web-app", ..#APP)
	do $$$AssertEquals(preview.grade, "reinforced")
	set system = ..Preview("DELETE /v2/web-app", "/csp/documatic")
	do $$$AssertEquals(system.grade, "maximum", "system application")
	do $$$AssertTrue(system.consequence [ "may stop working", system.consequence)
}

Method TestPctAccessDeleteIsReinforcedOnClass()
{
	set list = ##class(FlightDeck.Admin.Client).Get("/v2/web-app/pct-accesses", {"maxRows":1})
	set item = list.%Get(0)
	set request = {"operationId":"DELETE /v2/web-app/pct-access", "keys":{"name":(item.Name), "allowType":(item.AllowType), "class":(item.Class)}}
	set preview = ##class(FlightDeck.Mutation.Service).DoPreview(request, .status)
	do $$$AssertEquals(status, 200)
	do $$$AssertEquals(preview.grade, "reinforced")
	do $$$AssertEquals(preview.confirmText, item.Class)
}

}
