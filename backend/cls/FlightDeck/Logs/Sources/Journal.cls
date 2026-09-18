/// Journal records (feature 005 research R5).
/// <p>Read through the asynchronous helper, like the audit source. A journal record carries
/// <b>no user and no severity</b>: severity is "unknown" and user stays absent. Its DatabaseName is a
/// database, not a namespace, so it travels in the message and the raw record and never in the
/// namespace field, which would be a quiet lie.
/// <p>On the v1 dialect every journal operation is withheld, with the reason feature 001 recorded;
/// this source states it and the other four keep streaming.
Class FlightDeck.Logs.Sources.Journal [ Abstract ]
{

Parameter SOURCE = "journal";

/// How many journal files one page reads, newest first. Declared, because a busy instance keeps many.
Parameter MAXFILES = 2;

ClassMethod Available(Output reason As %String) As %Boolean
{
	set reason = ""
	for operationId = "GET /v2/journal/files", "POST /v2/journal/file/records" {
		if '##class(FlightDeck.Admin.Client).Has(operationId) {
			set reason = ##class(FlightDeck.Admin.Client).UnavailableReason(operationId)
			quit
		}
	}
	quit reason = ""
}

ClassMethod Page(query As %DynamicObject) As %DynamicObject
{
	set page = ##class(FlightDeck.Logs.Source).NewPage(..#SOURCE)
	if '..Available(.reason) quit ##class(FlightDeck.Logs.Source).Unavailable(page, reason)
	set files = ##class(FlightDeck.Admin.Client).Get("/v2/journal/files", {"maxRows":50}, .status, .raw)
	if (status '= 200) || '$isobject(files) quit ##class(FlightDeck.Logs.Source).Unavailable(page, ##class(FlightDeck.Admin.Client).ErrorText(files, raw))
	set limit = +$select($isobject(query) && (query.limit '= ""):query.limit, 1:100)
	set perFile = $select(limit>..#MAXFILES:limit\..#MAXFILES, 1:limit)
	set names = [], iter = files.%GetIterator()
	while iter.%GetNext(, .file) { do names.%Push(file.Name) }
	set count = names.%Size(), taken = 0
	for i = count-1:-1:0 {
		quit:taken>=..#MAXFILES
		set taken = taken + 1
		do ..ReadFile(page, names.%Get(i), perFile)
	}
	if count > ..#MAXFILES do page.unread.%Push("journal files older than the newest " _ ..#MAXFILES)
	set page.read = page.events.%Size()
	quit page
}

ClassMethod ReadFile(page As %DynamicObject, file As %String, limit As %Integer)
{
	set answer = ##class(FlightDeck.Async.Runner).FireAndFollow("POST /v2/journal/file/records", {"file":(file), "maxRows":(limit)}, 4)
	if answer.state = "Failed" {
		do page.unread.%Push(file _ " (" _ $select(answer.message'="":answer.message, 1:"refused") _ ")")
		quit
	}
	if answer.inFlight {
		do page.unread.%Push(file _ " (the instance is still collecting its records)")
		quit
	}
	set rows = answer.value
	quit:'$isobject(rows)
	quit:rows.%ClassName(1)'="%Library.DynamicArray"
	set iter = rows.%GetIterator()
	while iter.%GetNext(, .row) {
		continue:'$isobject(row)
		set address = $select(row.%IsDefined("Address"):row.Address, 1:"")
		set type = $select(row.%IsDefined("TypeName"):row.TypeName, 1:"")
		set node = $select(row.%IsDefined("GlobalNode"):row.GlobalNode, 1:"")
		set database = $select(row.%IsDefined("DatabaseName"):row.DatabaseName, 1:"")
		// The database is named in the message, not in the namespace field: they are different things.
		set message = type _ $select(node'="":" " _ node, 1:"") _ $select(database'="":" in " _ database, 1:"")
		set event = ##class(FlightDeck.Logs.Event).New(
			..#SOURCE, file _ ":" _ address, $select(row.%IsDefined("TimeStamp"):row.TimeStamp, 1:""),
			"unknown", message, row,
			{"process":($select(row.%IsDefined("ProcessID"):row.ProcessID, 1:""))})
		// What the record read needs, carried so the original can be fetched when the event is opened.
		set event.rawKey = {"file":(file), "address":(address)}
		do page.events.%Push(event)
	}
}

/// The original record, read on demand from the key the event carried.
ClassMethod Raw(key As %DynamicObject, Output reason As %String) As %DynamicObject
{
	set reason = ""
	set json = ##class(FlightDeck.Admin.Client).Get("/v2/journal/file/record", {"file":(key.file), "address":(key.address)}, .status, .raw)
	if (status '= 200) || '$isobject(json) {
		set reason = ##class(FlightDeck.Admin.Client).ErrorText(json, raw)
		set:reason="" reason = "The instance no longer holds this journal record: the file may have been purged."
		quit ""
	}
	quit json
}

}
