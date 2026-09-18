/// Link provider "task-upcoming": what the instance will run next.
Class FlightDeck.Domain.Links.TaskUpcoming [ Abstract ]
{

ClassMethod Operations() As %List
{
	quit $listbuild("GET /v2/task/upcoming")
}

ClassMethod Group(entity As %DynamicObject, params As %DynamicObject = "") As %DynamicObject
{
	set group = ##class(FlightDeck.Domain.LinkProviders).NewGroup("task-upcoming", "next scheduled runs", "out")
	set sc = ##class(FlightDeck.Domain.Upstream).Call("GET", "/v2/task/upcoming", {"maxRows":1000}, "", .status, .json, .raw)
	if $$$ISERR(sc) set status = 500, raw = $system.Status.GetErrorText(sc)
	if status '= 200 quit ##class(FlightDeck.Domain.LinkProviders).FromFailure(group, "GET /v2/task/upcoming", status, $get(json), $get(raw))
	set iter = $select($isobject(json) && $isobject(json.result):json.result, 1:[]).%GetIterator()
	while iter.%GetNext(, .row) {
		do group.items.%Push({"entityType":"task", "domain":"system", "displayName":(row.Name), "keys":{"id":(row.Id)}, "detail":(row.Datetime)})
	}
	set group.count = group.items.%Size()
	quit group
}

}
