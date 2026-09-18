/// Link provider "database-volumes": the volume files a database directory is stored in.
Class FlightDeck.Domain.Links.DatabaseVolumes [ Abstract ]
{

ClassMethod Operations() As %List
{
	quit $listbuild("GET /v2/database-dir/volumes")
}

ClassMethod Group(entity As %DynamicObject, params As %DynamicObject = "") As %DynamicObject
{
	set group = ##class(FlightDeck.Domain.LinkProviders).NewGroup("database-volumes", "volume files", "out")
	set sc = ##class(FlightDeck.Domain.Upstream).Call("GET", "/v2/database-dir/volumes", {"dir":(entity.keys.dir)}, "", .status, .json, .raw)
	if $$$ISERR(sc) set status = 500, raw = $system.Status.GetErrorText(sc)
	if status '= 200 quit ##class(FlightDeck.Domain.LinkProviders).FromFailure(group, "GET /v2/database-dir/volumes", status, $get(json), $get(raw))
	set iter = $select($isobject(json) && $isobject(json.result):json.result, 1:[]).%GetIterator()
	while iter.%GetNext(, .row) {
		do group.items.%Push({"entityType":"database-dir", "domain":"system", "displayName":(row.File), "keys":{"dir":(entity.keys.dir)}, "detail":(row.VolumeDirectory)})
	}
	set group.count = group.items.%Size()
	quit group
}

}
