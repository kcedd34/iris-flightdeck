/// Requires the demo objects (FlightDeck.Install.Demo) to exist.
Class FlightDeck.Test.PaletteSearch Extends %UnitTest.TestCase
{

Method OnBeforeAllTests() As %Status
{
	quit ##class(FlightDeck.Install.Demo).Provision()
}

Method Group(result As %DynamicObject, entityType As %String) As %DynamicObject
{
	set found = ""
	set iter = result.groups.%GetIterator()
	while iter.%GetNext(, .g) { if g.entityType = entityType { set found = g quit } }
	quit found
}

Method TestDemoObjectsFoundUnderTheirDomains()
{
	set result = ##class(FlightDeck.Palette.Search).Run("FD_Demo", "", 5)
	do $$$AssertNotTrue(result.degraded)
	for pair = "Role:permissions:2", "Resource:permissions:2", "Web application:web-apps:1", "Task:tasks:3", "Wallet collection:security:1" {
		set group = ..Group(result, $piece(pair, ":", 1))
		do $$$AssertTrue($isobject(group), "group "_$piece(pair, ":", 1))
		continue:'$isobject(group)
		do $$$AssertEquals(group.domain, $piece(pair, ":", 2))
		do $$$AssertEquals(group.total, $piece(pair, ":", 3), "count for "_$piece(pair, ":", 1))
		set first = group.results.%Get(0)
		do $$$AssertTrue((first.context '= "") && (first.target.route [ ("/"_group.domain_"/")), "context and route")
	}
}

Method TestExactMatchRanksFirst()
{
	set result = ##class(FlightDeck.Palette.Search).Run("fd_demo_operator", "permissions", 5)
	set roles = ..Group(result, "Role")
	do $$$AssertEquals(roles.results.%Get(0).name, "FD_Demo_Operator")
}

Method TestSeparatorsAreEquivalent()
{
	do $$$AssertEquals(##class(FlightDeck.Palette.Search).Normalize("FD_Demo"), "fddemo")
	do $$$AssertTrue(##class(FlightDeck.Palette.Search).Normalize("/csp/fd-demo") [ ##class(FlightDeck.Palette.Search).Normalize("FD_Demo"))
	do $$$AssertTrue(##class(FlightDeck.Palette.Search).Normalize("FD Demo daily no-op") [ ##class(FlightDeck.Palette.Search).Normalize("fd-demo"))
}

Method TestSearchableSetIsDerivedAndStable()
{
	set ops = ##class(FlightDeck.Palette.Search).Searchable()
	do $$$AssertTrue(ops.%Size() >= 25, "searchable operations: "_ops.%Size())
	set iter = ops.%GetIterator()
	while iter.%GetNext(, .op) {
		do $$$AssertEquals(op.method, "GET")
		do $$$AssertEquals(op.requiredParams.%Size(), 0)
	}
}

Method TestDomainFilterLimitsGroups()
{
	set result = ##class(FlightDeck.Palette.Search).Run("FD", "tasks", 5)
	set iter = result.groups.%GetIterator()
	while iter.%GetNext(, .g) { do $$$AssertEquals(g.domain, "tasks") }
}

}
