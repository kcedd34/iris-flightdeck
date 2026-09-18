/// The normalised log event (feature 005 data-model §1, RN-FD-23, RN-FD-24).
/// <p>One shape for five sources. Two rules hold it honest: <b>raw is mandatory</b> wherever the
/// original can be recovered, and where it cannot the gap is stated rather than filled in; and a
/// field the source does not provide is <b>absent</b>, never defaulted to something that looks like
/// an answer.
Class FlightDeck.Logs.Event [ Abstract ]
{

/// The normalised scale. "unknown" is a fifth value, outside the ordering: it is what a source that
/// states no level gets (feature 005 spec FR-003a, FR-003b). It is never inferred from message text —
/// a line reading "no errors found" is not an error, and guessing would make the screen lie quietly.
ClassMethod Severities() As %List
{
	quit $listbuild("info", "warning", "error", "fatal", "unknown")
}

/// Where a severity sits in the ordering, or "" for unknown, which has no place in it.
ClassMethod Rank(severity As %String) As %String
{
	quit $case(severity, "info":1, "warning":2, "error":3, "fatal":4, :"")
}

/// Builds one event. Absent fields are simply not set: the caller passes "" and they stay out.
ClassMethod New(source As %String, id As %String, timestamp As %String, severity As %String, message As %String, raw As %DynamicAbstractObject = "", fields As %DynamicObject = "") As %DynamicObject
{
	set event = {"id":(source _ ":" _ id), "source":(source), "timestamp":(timestamp), "message":(message)}
	do event.%Set("severity", $select($listfind(..Severities(), severity):severity, 1:"unknown"), "string")
	do event.%Set("parsed", 1, "boolean")
	if $isobject(fields) {
		set iter = fields.%GetIterator()
		while iter.%GetNext(.name, .value) {
			// "" means the source did not provide it; it stays absent rather than becoming empty.
			continue:value=""
			do event.%Set(name, value)
		}
	}
	if $isobject(raw) {
		set event.raw = raw
		do event.%Set("rawAvailable", 1, "boolean")
		do event.%Set("rawReason", "", "null")
	} else {
		do event.%Set("raw", "", "null")
		do event.%Set("rawAvailable", 0, "boolean")
		do event.%Set("rawReason", "", "null")
	}
	set event.correlate = ..Correlate(event)
	quit event
}

/// A line the source could not parse. It is kept as an event carrying the line itself: nothing is
/// dropped for being unreadable (spec FR-006).
ClassMethod Unparsed(source As %String, id As %String, line As %String, timestamp As %String = "") As %DynamicObject
{
	set event = ..New(source, id, timestamp, "unknown", line, {"line":(line)})
	do event.%Set("parsed", 0, "boolean")
	do event.%Set("rawAvailable", 1, "boolean")
	set event.raw = {"line":(line)}
	quit event
}

/// Marks an event whose original record cannot be recovered. The normalised fields stay; the gap is
/// stated where the record would be (spec FR-005).
ClassMethod RawGone(event As %DynamicObject, reason As %String) As %DynamicObject
{
	do event.%Set("raw", "", "null")
	do event.%Set("rawAvailable", 0, "boolean")
	do event.%Set("rawReason", reason, "string")
	quit event
}

/// The entities this event can open (RN-FD-26). Only fields the event actually carries.
ClassMethod Correlate(event As %DynamicObject) As %DynamicObject
{
	set out = {}
	for field = "process", "namespace", "user" {
		set value = $select(event.%IsDefined(field):event.%Get(field), 1:"")
		do:value'="" out.%Set(field, value)
	}
	quit out
}

}
