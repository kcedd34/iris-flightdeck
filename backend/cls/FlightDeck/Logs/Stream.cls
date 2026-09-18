/// The merge: several sources, one line (feature 005 data-model §4).
/// <p>Every source is asked for its own newest; the events are ordered by timestamp descending, with
/// ties broken on source and id so the order is stable between refreshes rather than shuffling.
/// <p>The answer always lists <b>every</b> source, including the ones that could not be read, with
/// their reason: what was read is part of the answer, not a detail (spec FR-010).
Class FlightDeck.Logs.Stream [ Abstract ]
{

/// Events one page returns, whatever the sources had.
Parameter LIMIT = 200;

ClassMethod Read(query As %DynamicObject) As %DynamicObject
{
	set limit = +$select($isobject(query) && (query.limit '= ""):query.limit, 1:..#LIMIT)
	set:limit>..#LIMIT limit = ..#LIMIT
	set selected = ..Selected(query)
	set answer = {"events":[], "sources":[], "timeZone":(..TimeZone())}
	do answer.%Set("cursor", "", "null")
	do answer.%Set("fileChanged", "", "null")
	set all = [], suppressed = 0
	// Each selected source contributes a share of the page, not the whole of it. One chatty source
	// otherwise fills every row and the other four become invisible — which is the problem a unified
	// stream exists to solve. The share is stated on the page, because "the newest N of each source"
	// is not the same claim as "the newest N events", and the screen must not imply the second.
	set count = 0, cit = selected.%GetIterator()
	while cit.%GetNext() { set count = count + 1 }
	set share = $select(count>0:limit\count, 1:limit)
	set:share<10 share = 10
	do answer.%Set("share", share, "number")
	set ptr = 0
	while $listnext(##class(FlightDeck.Logs.Source).Ids(), ptr, id) {
		set state = {"id":(id), "label":(##class(FlightDeck.Logs.Source).Label(id))}
		if 'selected.%IsDefined(id) {
			// Not asked for. It is still listed, so the screen shows the whole set of sources.
			do state.%Set("available", 1, "boolean")
			do state.%Set("selected", 0, "boolean")
			do state.%Set("read", 0, "number")
			do state.%Set("suppressed", 0, "number")
			do state.%Set("reason", "", "null")
			do answer.sources.%Push(state)
			continue
		}
		set page = ##class(FlightDeck.Logs.Source).Page(id, ..Query(query, share))
		do state.%Set("selected", 1, "boolean")
		do state.%Set("available", ''page.available, "boolean")
		do state.%Set("reason", page.reason, $select(page.reason="":"null", 1:"string"))
		do state.%Set("read", +page.read, "number")
		do state.%Set("suppressed", +page.suppressed, "number")
		if page.%IsDefined("unread"), page.unread.%Size() > 0 set state.unread = page.unread
		if page.%IsDefined("namespaces") set state.namespaces = page.namespaces
		if page.%IsDefined("changed"), page.changed '= "" set answer.fileChanged = page.changed
		do answer.sources.%Push(state)
		continue:'page.available
		set iter = page.events.%GetIterator()
		while iter.%GetNext(, .event) { do all.%Push(event) }
	}
	set ordered = ..Order(all)
	set kept = 0, iter = ordered.%GetIterator()
	while iter.%GetNext(, .event) {
		if kept >= limit { set suppressed = suppressed + 1 continue }
		continue:'..Matches(event, query)
		set kept = kept + 1
		do answer.events.%Push(event)
	}
	if suppressed > 0 {
		set answer.truncated = {"reason":"the per-refresh limit", "suppressed":(suppressed)}
	} else {
		do answer.%Set("truncated", "", "null")
	}
	quit answer
}

/// The sources asked for, or all of them.
ClassMethod Selected(query As %DynamicObject) As %DynamicObject
{
	set out = {}
	set asked = $select($isobject(query):query.%Get("sources"), 1:"")
	if asked = "" {
		set ptr = 0
		while $listnext(##class(FlightDeck.Logs.Source).Ids(), ptr, id) { do out.%Set(id, 1) }
		quit out
	}
	for i = 1:1:$length(asked, ",") {
		set id = $zstrip($piece(asked, ",", i), "<>W")
		do:id'="" out.%Set(id, 1)
	}
	quit out
}

ClassMethod Query(query As %DynamicObject, limit As %Integer) As %DynamicObject
{
	set out = {"limit":(limit)}
	quit:'$isobject(query) out
	for field = "from", "to", "cursor" { do:query.%Get(field)'="" out.%Set(field, query.%Get(field)) }
	quit out
}

/// Newest first, with a deterministic tie-break so two refreshes agree on the order.
ClassMethod Order(events As %DynamicArray) As %DynamicArray
{
	kill index
	set iter = events.%GetIterator(), n = 0
	while iter.%GetNext(, .event) {
		set n = n + 1
		set key = $select(event.timestamp'="":event.timestamp, 1:"0000")
		set index(key, event.source, event.id) = n
	}
	set out = [], key = ""
	for {
		set key = $order(index(key), -1)
		quit:key=""
		set source = ""
		for {
			set source = $order(index(key, source))
			quit:source=""
			set id = ""
			for {
				set id = $order(index(key, source, id))
				quit:id=""
				do out.%Push(events.%Get(index(key, source, id) - 1))
			}
		}
	}
	quit out
}

/// Severity and free text. The minimum severity never hides an unknown without being asked:
/// "unknown" is outside the ordering, so it is included unless the caller excludes it (spec FR-003c).
ClassMethod Matches(event As %DynamicObject, query As %DynamicObject) As %Boolean
{
	quit:'$isobject(query) 1
	set min = query.%Get("minSeverity")
	if min '= "" {
		set rank = ##class(FlightDeck.Logs.Event).Rank(event.severity)
		if rank = "" {
			// unknown: decided by its own switch, never by the threshold.
			quit:query.%Get("includeUnknown")="false" 0
		} else {
			quit:rank<##class(FlightDeck.Logs.Event).Rank(min) 0
		}
	}
	set text = query.%Get("q")
	if text '= "" {
		set haystack = $zconvert(event.message _ " " _ $select(event.%IsDefined("namespace"):event.namespace, 1:"") _ " " _ $select(event.%IsDefined("user"):event.user, 1:"") _ " " _ $select(event.%IsDefined("process"):event.process, 1:""), "L")
		quit:'(haystack [ $zconvert(text, "L")) 0
	}
	quit 1
}

/// The instance's time zone, stated once by the page: an event's time is a fact about the instance,
/// not about whoever is reading it.
ClassMethod TimeZone() As %String
{
	set offset = $ztimezone
	set sign = $select(offset>0:"-", 1:"+")
	set minutes = $zabs(offset)
	quit "UTC" _ sign _ $translate($justify(minutes\60, 2), " ", "0") _ ":" _ $translate($justify(minutes#60, 2), " ", "0")
}

}
