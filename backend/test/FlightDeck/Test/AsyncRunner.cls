/// Feature 004: the asynchronous value. What matters is that the last known value is never lost and
/// that a refusal carries the platform's own words (RN-FD-32, spec FR-023).
Class FlightDeck.Test.AsyncRunner Extends %UnitTest.TestCase
{

Method TestInFlightStates()
{
	for state = "Queued", "Running", "Paused" {
		do $$$AssertTrue(##class(FlightDeck.Async.Runner).InFlight(state), state_" is in flight")
	}
	for state = "Finished", "Failed", "Canceled" {
		do $$$AssertNotTrue(##class(FlightDeck.Async.Runner).InFlight(state), state_" is terminal")
	}
}

Method TestHandleComesFromTheLocationHeader()
{
	// The platform answers 202 with LOCATION naming /api/admin/v1/async-result even on v2. Only the
	// dialect layer reads that string, and it reads the id, not the path (research R6).
	kill headers
	set headers("location") = "/api/admin/v1/async-result?id=027625106990288105865181"
	do $$$AssertEquals(##class(FlightDeck.Admin.Client).AsyncHandle(.headers), "027625106990288105865181")
	kill headers
	do $$$AssertEquals(##class(FlightDeck.Admin.Client).AsyncHandle(.headers, {"GUID":"12345"}), "12345", "a future version may answer in the body")
	kill headers
	do $$$AssertEquals(##class(FlightDeck.Admin.Client).AsyncHandle(.headers), "", "no handle is reported as none, never invented")
}

Method TestReadOfAnUnknownHandleReportsThePlatform()
{
	set answer = ##class(FlightDeck.Async.Runner).Read("no-such-handle")
	do $$$AssertTrue($isobject(answer), "an answer is always returned")
	do $$$AssertNotEquals(answer.state, "Finished", "an unknown handle is not a finished value")
}

Method TestDiskValueSurvivesARefresh()
{
	// The disk instrument is the case this exists for: two readings in a row must both carry a value
	// or both explain why, and the second must never be blank because a refresh is running.
	set first = ##class(FlightDeck.Telemetry.Service).Reading()
	set second = ##class(FlightDeck.Telemetry.Service).Reading()
	set disk1 = ..Instrument(first, "disk"), disk2 = ..Instrument(second, "disk")
	do $$$AssertTrue($isobject(disk1) && $isobject(disk2), "the disk instrument keeps its place")
	if disk1.available {
		do $$$AssertTrue(disk2.available, "an available instrument stays available across a refresh")
		do $$$AssertNotEquals(disk2.value, "", "the number is never cleared by a refresh")
	}
}

ClassMethod Instrument(reading As %DynamicObject, id As %String) As %DynamicObject
{
	set iter = reading.instruments.%GetIterator()
	while iter.%GetNext(, .instrument) { quit:instrument.id=id }
	quit $select($isobject($get(instrument)) && (instrument.id = id):instrument, 1:"")
}

}
