/// Descriptor framework (feature 002 T011): shipped descriptors validate; privileges, unknown
/// operations and missing targets are rejected; predicate operators behave.
Class FlightDeck.Test.Descriptors Extends %UnitTest.TestCase
{

Method TestShippedDescriptorsAreValid()
{
	set problems = ##class(FlightDeck.Domain.Descriptor).Validate()
	do $$$AssertEquals(problems.%Size(), 0, problems.%ToJSON())
}

Method TestPrivilegeUnknownOperationAndMissingTargetRejected()
{
	set types = {"x/y": {"entityType":"y", "listOperation":"GET /v2/nope", "detailOperation":"GET /v2/web-app", "keys":[{"param":"name","field":"Name"}], "requires":["%Admin_Secure:U"], "markers":[]}}
	set mutations = {"DELETE /v2/web-app": {"kind":"delete", "readOperation":"GET /v2/web-app", "target":""}}
	set problems = ##class(FlightDeck.Domain.Descriptor).Validate(types, mutations).%ToJSON()
	do $$$AssertTrue(problems [ "declares 'requires'", problems)
	do $$$AssertTrue(problems [ "unknown operation 'GET /v2/nope'", problems)
	do $$$AssertTrue(problems [ "has no target", problems)
}

Method TestPredicateOperators()
{
	set ctx = {"proposed":{"Enabled":false, "AutheEnabled":64, "MatchRoles":[{"MatchRole":"", "TargetRoles":["Other"]}]}, "facts":{"runtimeRole":"FlightDeck_Runtime", "requiredAuthBits":32, "list":["a","b"]}, "changedFields":["NameSpace"], "object":{"Name":"/x", "Type":"System,CSP"}}
	set P = "FlightDeck.Domain.Predicate"
	do $$$AssertTrue($classmethod(P, "Eval", {"op":"true"}, ctx))
	do $$$AssertTrue($classmethod(P, "Eval", {"op":"equals", "path":"proposed.Enabled", "value":false}, ctx))
	do $$$AssertNotTrue($classmethod(P, "Eval", {"op":"equals", "path":"proposed.Missing", "value":false}, ctx), "undefined path is not equal")
	do $$$AssertTrue($classmethod(P, "Eval", {"op":"in", "path":"object.Name", "values":["/y","/x"]}, ctx))
	do $$$AssertTrue($classmethod(P, "Eval", {"op":"contains", "path":"object.Type", "value":"System"}, ctx))
	do $$$AssertTrue($classmethod(P, "Eval", {"op":"contains", "path":"facts.list", "value":"b"}, ctx))
	do $$$AssertTrue($classmethod(P, "Eval", {"op":"changed", "fields":["Enabled","NameSpace"]}, ctx))
	do $$$AssertNotTrue($classmethod(P, "Eval", {"op":"changed", "fields":["Enabled"]}, ctx))
	do $$$AssertTrue($classmethod(P, "Eval", {"op":"bitsCleared", "path":"proposed.AutheEnabled", "bitsPath":"facts.requiredAuthBits"}, ctx), "64 lacks bit 32")
	do $$$AssertNotTrue($classmethod(P, "Eval", {"op":"bitsCleared", "path":"proposed.AutheEnabled", "bitsPath":"proposed.AutheEnabled"}, ctx))
	do $$$AssertTrue($classmethod(P, "Eval", {"op":"lacksTargetRole", "path":"proposed.MatchRoles", "rolePath":"facts.runtimeRole"}, ctx))
	do $$$AssertTrue($classmethod(P, "Eval", {"op":"defined", "path":"proposed.Enabled"}, ctx))
	do $$$AssertTrue($classmethod(P, "Eval", {"op":"empty", "path":"proposed.Nothing"}, ctx))
	do $$$AssertTrue($classmethod(P, "Eval", {"op":"and", "all":[{"op":"true"}, {"op":"not", "expr":{"op":"equals", "path":"proposed.Enabled", "value":true}}]}, ctx))
	do $$$AssertTrue($classmethod(P, "Eval", {"op":"or", "any":[{"op":"equals", "path":"proposed.Enabled", "value":true}, {"op":"true"}]}, ctx))
	do $$$AssertEquals($classmethod(P, "Problem", {"op":"xecute"}, "object"), "unknown operator 'xecute'")
	do $$$AssertTrue($classmethod(P, "Problem", {"op":"equals", "path":"secret.x", "value":1}, "object,facts") [ "outside")
}

}
