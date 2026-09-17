/// GET /v1/session/capabilities: the full derived capability map (Constitution III).
Class FlightDeck.API.Capabilities [ Abstract ]
{

ClassMethod List() As %Status
{
	set sc = ##class(FlightDeck.Admin.Client).Call("GET", "/info", , , .status, .json, .raw)
	quit:$$$ISERR(sc) sc
	if (status '= 200) || '$isobject(json) {
		quit ##class(FlightDeck.API.Response).WriteError($select(status=403:403, 1:502), "UPSTREAM_ERROR", "The capability map could not be built.", ##class(FlightDeck.Admin.Client).ErrorText(json, raw))
	}
	set privileges = ##class(FlightDeck.Capability.Map).NormalizePrivileges(json.result.privileges)
	set response = {"entries":(##class(FlightDeck.Capability.Map).Build(privileges))}
	set response.composites = ##class(FlightDeck.Capability.Composite).Build(privileges)
	quit ##class(FlightDeck.API.Response).WriteJSON(response)
}

}
