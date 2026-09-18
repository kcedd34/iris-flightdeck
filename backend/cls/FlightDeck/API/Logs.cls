/// GET /v1/logs/events, /v1/logs/event/raw and /v1/logs/export (feature 005 contract).
/// <p>All three are reads: they stay available while safe mode is armed, as every read does.
Class FlightDeck.API.Logs [ Abstract ]
{

ClassMethod Events() As %Status
{
	quit ##class(FlightDeck.API.Response).WriteJSON(##class(FlightDeck.Logs.Stream).Read(..Query()))
}

/// The original record of one event, fetched when it is opened rather than carried with every row.
/// Where it cannot be recovered the answer says so, and the normalised fields still stand.
ClassMethod Raw() As %Status
{
	set source = $get(%request.Data("source", 1))
	set key = {}
	for param = "utcTimeStamp", "systemID", "auditIndex", "line" {
		do:$get(%request.Data(param, 1))'="" key.%Set(param, %request.Data(param, 1))
	}
	if source = "audit" {
		set raw = ##class(FlightDeck.Logs.Sources.Audit).Raw(key, .reason)
		if '$isobject(raw) {
			quit ##class(FlightDeck.API.Response).WriteJSON({"available":false, "raw":null, "reason":(reason)})
		}
		quit ##class(FlightDeck.API.Response).WriteJSON({"available":true, "raw":(raw), "reason":null})
	}
	// A file source carries its line with the event, so there is nothing further to fetch.
	if key.%IsDefined("line") {
		quit ##class(FlightDeck.API.Response).WriteJSON({"available":true, "raw":{"line":(key.line)}, "reason":null})
	}
	quit ##class(FlightDeck.API.Response).WriteJSON({"available":false, "raw":null, "reason":"This source does not keep a record beyond what the event already carries."})
}

/// The filtered result, with every event's original record, and a header naming the filters that
/// produced it and the sources that were unavailable when it was taken (spec FR-022, FR-023).
ClassMethod Export() As %Status
{
	set query = ..Query()
	set page = ##class(FlightDeck.Logs.Stream).Read(query)
	set export = {
		"filters":(query), "sources":(page.sources), "events":(page.events),
		"exportedAt":(##class(FlightDeck.Vitals.Service).Now()), "timeZone":(page.timeZone)
	}
	do %response.SetHeader("Content-Disposition", "attachment; filename=""flightdeck-logs.json""")
	quit ##class(FlightDeck.API.Response).WriteJSON(export)
}

ClassMethod Query() As %DynamicObject
{
	set query = {}
	for param = "sources", "from", "to", "minSeverity", "includeUnknown", "q", "taskId", "taskName", "cursor", "since", "limit" {
		do:$get(%request.Data(param, 1))'="" query.%Set(param, %request.Data(param, 1))
	}
	quit query
}

}
