/// The instance's messages log (feature 005 research R1).
/// <p>Its lines state their own severity: `MM/DD/YY-HH:MM:SS:mmm (pid) <level> [Category.Event] text`,
/// where <level> is the platform's own 0 to 3. The normalised severity is therefore a mapping of a
/// value the instance declared, not a judgement FlightDeck made.
Class FlightDeck.Logs.Sources.Messages [ Abstract ]
{

Parameter SOURCE = "messages";

/// The file, resolved from the instance. Never a hard-coded path: an instance may keep its manager
/// directory anywhere, and guessing would read someone else's log or none at all.
ClassMethod File() As %String
{
	quit ##class(%File).NormalizeFilename(..#FILENAME, $zutil(12))
}

Parameter FILENAME = "messages.log";

ClassMethod Available(Output reason As %String) As %Boolean
{
	set reason = ""
	set file = ..File()
	if '##class(%File).Exists(file) {
		set reason = "This instance has not written " _ file _ "."
		quit 0
	}
	quit 1
}

ClassMethod Page(query As %DynamicObject) As %DynamicObject
{
	set page = ##class(FlightDeck.Logs.Source).NewPage(..#SOURCE)
	if '..Available(.reason) quit ##class(FlightDeck.Logs.Source).Unavailable(page, reason)
	quit ..Read(page, ..File(), ..#SOURCE, query)
}

/// Shared by this source and the alerts source: both read IRIS-shaped log files.
ClassMethod Read(page As %DynamicObject, file As %String, source As %String, query As %DynamicObject) As %DynamicObject
{
	set limit = +$select($isobject(query) && (query.limit '= ""):query.limit, 1:100)
	set cursor = $select($isobject(query):query.%Get("cursor" _ source), 1:"")
	set answer = ##class(FlightDeck.Logs.Reader).Page(file, $select(cursor="":"", 1:cursor), , limit)
	if 'answer.available quit ##class(FlightDeck.Logs.Source).Unavailable(page, answer.reason)
	if answer.changed '= "" {
		set page.changed = answer.changed
	}
	set page.cursor = answer.cursor
	do page.%Set("exhausted", ''answer.exhausted, "boolean")
	set iter = answer.lines.%GetIterator(), n = 0
	while iter.%GetNext(, .line) {
		set n = n + 1
		do page.events.%Push(..Parse(source, file _ ":" _ answer.cursor _ ":" _ n, line))
	}
	set page.read = page.events.%Size()
	quit page
}

/// One line. A line that does not match the shape is kept as an event carrying the line itself: the
/// source never drops what it cannot read (spec FR-006).
ClassMethod Parse(source As %String, id As %String, line As %String) As %DynamicObject
{
	set stamp = $piece(line, " ", 1)
	set rest = $piece(line, " ", 2, *)
	// MM/DD/YY-HH:MM:SS:mmm, exactly as the instance writes it.
	if '(stamp ? 2N1"/"2N1"/"2N1"-"2N1":"2N1":"2N1":"3N) || '(rest [ "(") {
		quit ##class(FlightDeck.Logs.Event).Unparsed(source, id, line)
	}
	set pid = $piece($piece(rest, "(", 2), ")", 1)
	set after = $piece(rest, ")", 2, *)
	set level = $zstrip($piece(after, " ", 2), "<>W")
	set category = $piece($piece(after, "[", 2), "]", 1)
	set message = $zstrip($piece(after, "]", 2, *), "<>W")
	set:message="" message = $zstrip(after, "<>W")
	set event = ##class(FlightDeck.Logs.Event).New(
		source, id, ..Timestamp(stamp), ..Severity(level),
		$select(category'="":category _ ": ", 1:"") _ message,
		{"line":(line)},
		{"process":(pid)})
	quit event
}

/// The platform's own level, mapped: 0 info, 1 warning, 2 error, 3 fatal. Anything else is unknown,
/// because a level FlightDeck does not recognise is not a level it may invent.
ClassMethod Severity(level As %String) As %String
{
	quit $case(level, 0:"info", 1:"warning", 2:"error", 3:"fatal", :"unknown")
}

/// "09/18/26-04:45:26:546" as the instance writes it, to "2026-09-18 04:45:26.546".
ClassMethod Timestamp(stamp As %String) As %String
{
	set date = $piece(stamp, "-", 1), time = $piece(stamp, "-", 2)
	quit:'(date ? 2N1"/"2N1"/"2N) stamp
	set year = $piece(date, "/", 3)
	set year = $select($length(year)=2:"20" _ year, 1:year)
	quit year _ "-" _ $piece(date, "/", 1) _ "-" _ $piece(date, "/", 2) _ " " _ $piece(time, ":", 1, 3) _ "." _ $piece(time, ":", 4)
}

}
