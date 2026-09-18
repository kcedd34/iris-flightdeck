/// Audit records (feature 005 research R6).
/// <p>The listing answers asynchronously, so it is read through the helper feature 004 built — the
/// same one that serves the disk instrument, the long storage operations and the journal source.
/// <p>Each row carries its own three-part key (utcTimeStamp, systemID, auditIndex), which is exactly
/// what GET /v2/security/audit/record requires: the original record is one read away, fetched when
/// the event is opened rather than carried with every row.
Class FlightDeck.Logs.Sources.Audit [ Abstract ]
{

Parameter SOURCE = "audit";

ClassMethod Available(Output reason As %String) As %Boolean
{
	set reason = ""
	if '##class(FlightDeck.Admin.Client).Has("POST /v2/security/audit/records") {
		set reason = ##class(FlightDeck.Admin.Client).UnavailableReason("POST /v2/security/audit/records")
		quit 0
	}
	// Auditing switched off is the instance's own answer, not a refusal: it is reported with the
	// reason and with where to turn it on (spec FR-011, UC09 A5).
	set enabled = ##class(FlightDeck.Admin.Client).Get("/v2/security/audit/enabled", , .status)
	if (status = 200) && $isobject(enabled) && 'enabled.Enabled {
		set reason = "Auditing is switched off on this instance, so it is recording nothing. Turn it on in Security and secrets, Auditing."
		quit 0
	}
	quit 1
}

ClassMethod Page(query As %DynamicObject) As %DynamicObject
{
	set page = ##class(FlightDeck.Logs.Source).NewPage(..#SOURCE)
	if '..Available(.reason) quit ##class(FlightDeck.Logs.Source).Unavailable(page, reason)
	set limit = +$select($isobject(query) && (query.limit '= ""):query.limit, 1:100)
	set params = {"maxRows":(limit), "ascending":0}
	if $isobject(query) {
		do:query.%Get("from")'="" params.%Set("beginDateTime", query.from)
		do:query.%Get("to")'="" params.%Set("endDateTime", query.to)
	}
	set answer = ##class(FlightDeck.Async.Runner).FireAndFollow("POST /v2/security/audit/records", params, 4)
	if answer.state = "Failed" quit ##class(FlightDeck.Logs.Source).Unavailable(page, $select(answer.message'="":answer.message, 1:"The instance refused the audit record listing."))
	if answer.inFlight {
		// Still collecting: say so rather than answer an empty page, which would read as "nothing
		// was audited" (RN-FD-32).
		quit ##class(FlightDeck.Logs.Source).Unavailable(page, "The instance is still collecting audit records (state " _ answer.state _ "). They appear on the next refresh.")
	}
	set rows = answer.value
	if '$isobject(rows) || (rows.%ClassName(1) '= "%Library.DynamicArray") set rows = []
	set iter = rows.%GetIterator()
	while iter.%GetNext(, .row) {
		continue:'$isobject(row)
		do page.events.%Push(..Normalise(row))
	}
	set page.read = page.events.%Size()
	quit page
}

ClassMethod Normalise(row As %DynamicObject) As %DynamicObject
{
	set index = $select(row.%IsDefined("AuditIndex"):row.AuditIndex, 1:"")
	set stamp = $select(row.%IsDefined("UTCTimeStamp"):row.UTCTimeStamp, 1:"")
	set system = $select(row.%IsDefined("SystemID"):row.SystemID, 1:"")
	set event = $select(row.%IsDefined("Event"):row.Event, 1:"")
	set description = $select(row.%IsDefined("Description"):row.Description, 1:"")
	set message = event _ $select(description'="":" · " _ description, 1:"")
	set normalised = ##class(FlightDeck.Logs.Event).New(
		..#SOURCE, index _ "|" _ stamp _ "|" _ system, stamp, ..Severity(row), message, row,
		{"namespace":($select(row.%IsDefined("Namespace"):row.Namespace, 1:"")),
		 "process":($select(row.%IsDefined("Pid"):row.Pid, 1:"")),
		 "user":($select(row.%IsDefined("Username"):row.Username, 1:""))})
	// The key the detail read needs, carried so the original record can be fetched on demand.
	set normalised.rawKey = {"utcTimeStamp":(stamp), "systemID":(system), "auditIndex":(index)}
	quit normalised
}

/// An audit record states no level. Where it recorded a failure the severity is error; otherwise it
/// is unknown, because "the record did not say" is a fact and "info" would be an invention.
ClassMethod Severity(row As %DynamicObject) As %String
{
	set status = $select(row.%IsDefined("Status"):row.Status, 1:"")
	quit $select(status'="":"error", 1:"unknown")
}

/// The original record, read on demand from the key the event carried.
ClassMethod Raw(key As %DynamicObject, Output reason As %String) As %DynamicObject
{
	set reason = ""
	set json = ##class(FlightDeck.Admin.Client).Get("/v2/security/audit/record", {"utcTimeStamp":(key.utcTimeStamp), "systemID":(key.systemID), "auditIndex":(key.auditIndex)}, .status, .raw)
	if (status '= 200) || '$isobject(json) {
		set reason = ##class(FlightDeck.Admin.Client).ErrorText(json, raw)
		set:reason="" reason = "The instance no longer holds this audit record."
		quit ""
	}
	quit json
}

}
