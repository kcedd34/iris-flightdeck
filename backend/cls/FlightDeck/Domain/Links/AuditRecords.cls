/// Link provider "audit-records": the most recent audit records, as the security domain's own read.
/// <p>The unified log flow is feature 005's (feature 003 decided that boundary: mutation here,
/// reading there). This group is the raw read the security domain owns, bounded and unfiltered, so
/// an administrator can see that auditing is producing records without leaving the section.
Class FlightDeck.Domain.Links.AuditRecords [ Abstract ]
{

Parameter MAXROWS = 20;

ClassMethod Operations() As %List
{
	quit $listbuild("POST /v2/security/audit/records")
}

ClassMethod Group(entity As %DynamicObject, params As %DynamicObject = "") As %DynamicObject
{
	set group = ##class(FlightDeck.Domain.LinkProviders).NewGroup("audit-records", "most recent audit records", "out")
	// The official operation lists with POST because its filters are many, and it answers 202: the
	// records arrive through the same asynchronous mechanism as the disk metrics (feature 004). It
	// changes nothing; it is a read that the platform runs as a task.
	// Its boolean query parameters reject "false" and want 0 or 1 (probed 2026-09-18).
	set answer = ##class(FlightDeck.Async.Runner).FireAndFollow("POST /v2/security/audit/records", {"maxRows":(..#MAXROWS), "ascending":0}, 3)
	if answer.state = "Failed" {
		set group.state = "undetermined"
		set group.reason = $select(answer.message'="":answer.message, 1:"The instance refused the audit record listing.")
		quit group
	}
	if answer.inFlight {
		// Still running: the group says so rather than showing an empty list, which would read as
		// "auditing recorded nothing" (RN-FD-32).
		set group.state = "undetermined"
		set group.reason = "The instance is still collecting the records (state " _ answer.state _ ")."
		quit group
	}
	// The platform answers the records as a plain array. %IsDefined("name") returns true on a
	// DynamicArray, so an unwrap guarded that way would empty the list instead of leaving it alone:
	// the shape is checked before anything is read from it.
	set rows = answer.value
	if $isobject(rows), rows.%ClassName(1) = "%Library.DynamicObject", rows.%IsDefined("AuditRecords") set rows = rows.AuditRecords
	if '$isobject(rows) || (rows.%ClassName(1) '= "%Library.DynamicArray") set rows = []
	set iter = rows.%GetIterator()
	while iter.%GetNext(, .row) {
		continue:'$isobject(row)
		set name = $select(row.%IsDefined("Event"):row.Event, row.%IsDefined("Name"):row.Name, 1:"")
		set stamp = $select(row.%IsDefined("UTCTimeStamp"):row.UTCTimeStamp, row.%IsDefined("TimeStamp"):row.TimeStamp, 1:"")
		set who = $select(row.%IsDefined("Username"):row.Username, 1:"")
		do group.items.%Push({
			"entityType":"audit-record", "domain":"security", "displayName":($zstrip(stamp _ " " _ name, "<>W")),
			"keys":{}, "detail":(who)
		})
	}
	set group.count = group.items.%Size()
	quit group
}

}
