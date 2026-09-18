/// The source contract and registry (feature 005 contracts/log-sources.md).
/// <p>Five sources exist; a sixth would implement Page() and declare itself here, and nothing else.
/// A source never states a privilege: availability comes from the capability map for the official
/// operations it calls, or from what the instance answered for the ones it reads itself
/// (Constitution III).
Class FlightDeck.Logs.Source [ Abstract ]
{

/// id -> class. The two official sources are asynchronous; the two file sources share the reader;
/// the interoperability source reads SQL, per namespace.
ClassMethod Class(id As %String) As %String
{
	quit $case(id,
		"audit":"FlightDeck.Logs.Sources.Audit",
		"journal":"FlightDeck.Logs.Sources.Journal",
		"messages":"FlightDeck.Logs.Sources.Messages",
		"alerts":"FlightDeck.Logs.Sources.Alerts",
		"interop":"FlightDeck.Logs.Sources.Interop",
		:"")
}

ClassMethod Ids() As %List
{
	quit $listbuild("audit", "journal", "messages", "alerts", "interop")
}

ClassMethod Label(id As %String) As %String
{
	quit $case(id,
		"audit":"Audit records",
		"journal":"Journal records",
		"messages":"System messages",
		"alerts":"Alerts",
		"interop":"Interoperability",
		:id)
}

/// An empty page with a state. Used by every source, so the shape is the same whatever went wrong.
ClassMethod NewPage(id As %String) As %DynamicObject
{
	set page = {"id":(id), "label":(..Label(id)), "events":[], "cursor":"", "read":0, "suppressed":0, "unread":[]}
	do page.%Set("available", 1, "boolean")
	do page.%Set("reason", "", "null")
	quit page
}

/// A source that cannot be read says why, in the platform's own words where there are any, and where
/// the instance can enable it, where that is done. It never answers an empty page, which would read
/// as "nothing happened" (spec FR-010).
ClassMethod Unavailable(page As %DynamicObject, reason As %String) As %DynamicObject
{
	do page.%Set("available", 0, "boolean")
	do page.%Set("reason", reason, "string")
	quit page
}

/// Whether the session can read this source at all, asked before a page is fetched.
ClassMethod Available(id As %String, Output reason As %String) As %Boolean
{
	set reason = "", class = ..Class(id)
	quit:class="" 0
	quit $classmethod(class, "Available", .reason)
}

/// One page of one source.
ClassMethod Page(id As %String, query As %DynamicObject) As %DynamicObject
{
	set class = ..Class(id)
	quit:class="" ..Unavailable(..NewPage(id), "Unknown source.")
	quit $classmethod(class, "Page", query)
}

}
