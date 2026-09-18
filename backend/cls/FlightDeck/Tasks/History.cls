/// Recent run history per task, from one read of the instance's history (feature 004 research R7).
/// <p><em>GET /v2/task/history</em> accepts an <var>id</var> parameter and ignores it: it answers the
/// whole instance's history, every row carrying its own TaskId (probed 2026-09-18,
/// verification/README.md). FlightDeck reads it once and groups by TaskId, which is also what makes
/// the compact history band affordable: a list of forty tasks costs one request, not forty.
/// <p>The platform defect is worked around here and documented there; it is never masked.
Class FlightDeck.Tasks.History [ Abstract ]
{

/// How many runs the band keeps per task. Enough to show an intermittent failure without turning the
/// list into a log (RN-FD-17).
Parameter BAND = 8;

/// Runs by task id: bands(taskId) = %DynamicArray of {at, result, durationSeconds, running, message}.
/// <var>complete</var> is 0 when the history could not be read, so a screen can say the band is
/// unknown instead of showing an empty band as if there had been no runs.
ClassMethod Bands(Output complete As %Boolean, Output reason As %String) As %DynamicObject
{
	set complete = 0, reason = "", bands = {}
	if '##class(FlightDeck.Admin.Client).Has("GET /v2/task/history") {
		set reason = ##class(FlightDeck.Admin.Client).UnavailableReason("GET /v2/task/history")
		quit bands
	}
	set rows = ##class(FlightDeck.Admin.Client).Get("/v2/task/history", {"maxRows":"1000"}, .status, .raw)
	if (status '= 200) || '$isobject(rows) {
		set reason = ##class(FlightDeck.Admin.Client).ErrorText(rows, raw)
		quit bands
	}
	set complete = 1
	set iter = rows.%GetIterator()
	while iter.%GetNext(, .row) {
		set id = $select(row.%IsDefined("TaskId"):row.TaskId, 1:"")
		continue:id=""
		set key = "t" _ id
		if 'bands.%IsDefined(key) do bands.%Set(key, [])
		set band = bands.%Get(key)
		continue:band.%Size()>=..#BAND
		set entry = ..Run(row)
		// The band is about runs. A lifecycle entry stays available for the detail, where the whole
		// history is shown, but it is never a result in the list.
		continue:entry.kind'="run"
		do band.%Push(entry)
	}
	quit bands
}

/// One history entry, in FlightDeck's shape.
/// <p>The instance's history mixes runs with lifecycle entries: beside "Success" it records
/// "Create <task>", "Suspended task", "Resumed task" and "Task Has Expired for ..." — all with
/// Status 1 and ErrNumber 0 (probed 2026-09-18, verification/README.md). Reading anything that is
/// not "Success" as a failure would paint healthy tasks as failing, so FlightDeck classifies:
/// a run is a row the platform marked Success or recorded an error number for; everything else is
/// an event, kept with the platform's own words and shown in the detail, never counted as a result.
ClassMethod Run(row As %DynamicObject) As %DynamicObject
{
	set start = $select(row.%IsDefined("LastStart"):row.LastStart, 1:"")
	set completed = $select(row.%IsDefined("Completed"):row.Completed, 1:"")
	set result = $select(row.%IsDefined("Result"):row.Result, 1:"")
	set errNumber = +$select(row.%IsDefined("ErrNumber"):row.ErrNumber, 1:0)
	set status = $select(row.%IsDefined("Status"):row.Status, 1:"")
	// A failed run is recorded with ErrNumber 1 and the error text in Status, leaving Result empty
	// (probed 2026-09-18). A successful one has Status 1 and Result "Success". So the message is read
	// from wherever the platform put it, and never composed by FlightDeck.
	set failed = (errNumber '= 0) || ((status '= "") && (status '= 1))
	set text = $select(failed && (status '= 1) && (status '= ""):status, 1:result)
	set run = {"at":(start), "completed":(completed)}
	do run.%Set("kind", $select(failed:"run", result="Success":"run", 1:"event"), "string")
	do run.%Set("result", $select(failed:"Error", result="Success":"Success", 1:""), "string")
	do run.%Set("platformResult", $select(text'="":text, 1:result), "string")
	do run.%Set("running", (start '= "") && (completed = ""), "boolean")
	// An unknown duration is null, never 0: "" coerced to a number would report a run that took no
	// time, which is a fact the platform never stated.
	set duration = ..Duration(start, completed)
	do run.%Set("durationSeconds", duration, $select(duration="":"null", 1:"number"))
	do run.%Set("message", $select(failed:text, 1:""), "string")
	do run.%Set("namespace", $select(row.%IsDefined("Namespace"):row.Namespace, 1:""), "string")
	do run.%Set("routine", $select(row.%IsDefined("Routine"):row.Routine, 1:""), "string")
	do run.%Set("pid", $select(row.%IsDefined("Pid"):row.Pid, 1:""), "string")
	quit run
}

/// Seconds between two platform timestamps ("YYYY-MM-DD HH:MM:SS"), or "" when either is missing or
/// unreadable. An unreadable timestamp is reported as unknown, never as zero.
ClassMethod Duration(start As %String, completed As %String) As %String
{
	quit:(start="")||(completed="") ""
	set from = ..Seconds(start), to = ..Seconds(completed)
	quit:(from="")||(to="") ""
	quit:to<from ""
	quit to - from
}

ClassMethod Seconds(stamp As %String) As %String
{
	set date = $piece(stamp, " ", 1), time = $piece(stamp, " ", 2)
	quit:(date="")||(time="") ""
	set days = $zdatetimeh(date _ " " _ time, 3, 1, , , , , , , "")
	quit:days="" ""
	quit ($piece(days, ",", 1) * 86400) + $piece(days, ",", 2)
}

/// The band of one task, or an empty array when it has none.
ClassMethod Band(bands As %DynamicObject, id As %String) As %DynamicArray
{
	quit:'$isobject(bands) []
	set key = "t" _ id
	quit $select(bands.%IsDefined(key):bands.%Get(key), 1:[])
}

}
