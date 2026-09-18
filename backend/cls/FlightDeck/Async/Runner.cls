/// Fire-and-poll for the platform's asynchronous operations (feature 004 data-model §4.2).
/// <p>Some official operations answer 202 and finish later: disk space per database, and the three
/// long storage operations (compact, defragment, integrity check). The platform hands back a handle;
/// FlightDeck fires, keeps the handle, and reads the result when asked.
/// <p>The one rule this class exists to protect: the caller always gets the last known value back.
/// A refresh in flight never clears a number and never replaces it with a loading indicator
/// (RN-FD-32, spec FR-023). Failure carries the platform's own message beside the value, never
/// instead of it.
Class FlightDeck.Async.Runner [ Abstract ]
{

/// States the platform reports, plus "idle" for a value never fired.
/// Queued, Running and Paused are in flight; Finished, Failed and Canceled are terminal.
ClassMethod InFlight(state As %String) As %Boolean
{
	quit (state = "Queued") || (state = "Running") || (state = "Paused")
}

/// Fires an operation that answers 202 and returns its handle, or "" with the reason in
/// <var>message</var>.
ClassMethod Fire(operationId As %String, query As %DynamicObject = "", body As %DynamicAbstractObject = "", Output message As %String) As %String
{
	set message = ""
	set method = $piece(operationId, " ", 1), path = $piece(operationId, " ", 2, *)
	set sc = ##class(FlightDeck.Admin.Client).Call(method, path, query, body, .status, .json, .raw, .headers)
	if $$$ISERR(sc) {
		set message = $system.Status.GetErrorText(sc)
		quit ""
	}
	if (status '= 200) && (status '= 202) {
		set message = ##class(FlightDeck.Admin.Client).ErrorText(json, raw)
		quit ""
	}
	set handle = ##class(FlightDeck.Admin.Client).AsyncHandle(.headers, json)
	if handle = "" set message = "The instance accepted the request but returned no handle to follow it with."
	quit handle
}

/// Reads a fired operation. Always returns an object: state, the platform's message when it has one,
/// and the value when the task finished.
ClassMethod Read(handle As %String) As %DynamicObject
{
	set answer = {"state":"idle", "handle":(handle), "message":"", "value":""}
	quit:handle="" answer
	set json = ##class(FlightDeck.Admin.Client).Get("/v2/async-result", {"id":(handle)}, .status, .raw)
	if status '= 200 {
		set answer.state = "Failed"
		set answer.message = ##class(FlightDeck.Admin.Client).ErrorText(json, raw)
		quit answer
	}
	set answer.state = $select($isobject(json) && (json.State '= ""):json.State, 1:"idle")
	if $isobject(json) {
		set answer.message = $select(json.%IsDefined("FailureReason"):json.FailureReason, 1:"")
		do answer.%Set("value", $select(json.%IsDefined("Result"):json.Result, 1:""))
		do answer.%Set("taskName", $select(json.%IsDefined("TaskName"):json.TaskName, 1:""), "string")
		do answer.%Set("timeQueued", $select(json.%IsDefined("TimeQueued"):json.TimeQueued, 1:""), "string")
		do answer.%Set("timeFinished", $select(json.%IsDefined("TimeFinished"):json.TimeFinished, 1:""), "string")
		// The platform reports a failed task with a state, not an HTTP error; the console lines are
		// the only explanation it gives for some of them, so they are carried as they are.
		if (answer.message = "") && json.%IsDefined("Console") && $isobject(json.Console) && (json.Console.%Size() > 0) {
			set answer.message = json.Console.%Get(0)
		}
	}
	do answer.%Set("inFlight", ..InFlight(answer.state), "boolean")
	quit answer
}

/// Fires an operation and waits only as long as <var>seconds</var> for it, returning whatever state
/// it has reached. Nothing here blocks a screen: the caller decides how long it is willing to wait,
/// and the value that was already known stays on screen either way.
ClassMethod FireAndFollow(operationId As %String, query As %DynamicObject = "", seconds As %Integer = 2, body As %DynamicAbstractObject = "") As %DynamicObject
{
	set handle = ..Fire(operationId, query, body, .message)
	if handle = "" quit {"state":"Failed", "handle":"", "message":(message), "value":"", "inFlight":false}
	set deadline = $piece($horolog, ",", 2) + seconds
	for {
		set answer = ..Read(handle)
		quit:'answer.inFlight
		quit:$piece($horolog, ",", 2)>=deadline
		hang 0.2
	}
	quit answer
}

}
