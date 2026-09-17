/// 30-second cache for link provider results (feature 002 research R6). Scoped to the IRIS session,
/// so results never cross users; outside a web request (unit tests) it is scoped to the process and
/// the user name. Any applied mutation invalidates it.
Class FlightDeck.Domain.LinkCache [ Abstract ]
{

Parameter SECONDS = 30;

ClassMethod Get(key As %String, Output value As %DynamicAbstractObject) As %Boolean
{
	set value = ""
	set entry = $select(..InSession():$get(%session.Data("fd.links", key)), 1:$get(%FlightDeckLinks($username, key)))
	quit:entry="" 0
	quit:(($zhorolog - $list(entry, 1)) >= ..#SECONDS) 0
	set value = ##class(%DynamicAbstractObject).%FromJSON($list(entry, 2))
	quit 1
}

ClassMethod Set(key As %String, value As %DynamicAbstractObject)
{
	set entry = $listbuild($zhorolog, value.%ToJSON())
	if ..InSession() { set %session.Data("fd.links", key) = entry } else { set %FlightDeckLinks($username, key) = entry }
}

ClassMethod Invalidate()
{
	if ..InSession() kill %session.Data("fd.links")
	kill %FlightDeckLinks
}

ClassMethod InSession() As %Boolean
{
	quit ($data(%session)#2) && $isobject($get(%session)) && (%session.SessionId '= "")
}

}
