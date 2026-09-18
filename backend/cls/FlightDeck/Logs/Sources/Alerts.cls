/// Alerts, as the instance writes them (feature 005 research R3).
/// <p><b>A stock instance writes no alerts log.</b> IRIS creates one only where the System Monitor's
/// alert handling is configured, so "absent, with the reason" is this source's normal state — not an
/// error, and never an empty page, which would read as "no alerts have happened".
/// <p>Deriving alerts from the messages log by severity was considered and rejected: it would report
/// an alert the instance never raised, and what the platform escalated is the whole point.
Class FlightDeck.Logs.Sources.Alerts [ Abstract ]
{

Parameter SOURCE = "alerts";

/// The files this source reads, in order: the alerts log, and the System Monitor's own log where it
/// exists (that is where the monitor states what it raised).
ClassMethod Files() As %List
{
	set dir = $zutil(12)
	quit $listbuild(##class(%File).NormalizeFilename("alerts.log", dir), ##class(%File).NormalizeFilename("SystemMonitor.log", dir))
}

ClassMethod Available(Output reason As %String) As %Boolean
{
	set reason = "", ptr = 0
	while $listnext(..Files(), ptr, file) { quit:##class(%File).Exists(file) }
	if $get(file) = "" || '##class(%File).Exists($get(file)) {
		set reason = "This instance writes no alerts log. Alerts are configured in System Monitor, and appear here once it writes one."
		quit 0
	}
	quit 1
}

ClassMethod Page(query As %DynamicObject) As %DynamicObject
{
	set page = ##class(FlightDeck.Logs.Source).NewPage(..#SOURCE)
	if '..Available(.reason) quit ##class(FlightDeck.Logs.Source).Unavailable(page, reason)
	set ptr = 0
	while $listnext(..Files(), ptr, file) {
		continue:'##class(%File).Exists(file)
		set partial = ##class(FlightDeck.Logs.Sources.Messages).Read(##class(FlightDeck.Logs.Source).NewPage(..#SOURCE), file, ..#SOURCE, query)
		continue:'partial.available
		set iter = partial.events.%GetIterator()
		while iter.%GetNext(, .event) { do page.events.%Push(event) }
		set:partial.cursor'="" page.cursor = partial.cursor
	}
	set page.read = page.events.%Size()
	quit page
}

}
