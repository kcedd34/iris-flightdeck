/// One reading of the instrument cluster (feature 004 contracts/flightdeck-api-004.openapi.json).
/// <p>The whole cluster answers in one call, so five instruments are not five requests per second.
/// The sliding window is not here: it lives in the client session and is never persisted
/// (RN-FD-21, spec FR-018).
/// <p>Transport is polling. The official API offers no streaming endpoint, and a FlightDeck-owned
/// one would poll the platform on the server while holding a long-lived connection behind the web
/// gateway, with nothing an administrator could observe that polling does not already give
/// (spec FR-020a, research R1). The mode is reported so the screen can state it.
/// <p>CPU, memory, shared memory and disk come from FlightDeck.Vitals.Service, which already reads
/// the native host metrics and the asynchronous disk value: the home panel and this cluster cannot
/// disagree because they read the same thing (spec FR-046).
Class FlightDeck.Telemetry.Service [ Abstract ]
{

Parameter MODE = "polling";

Parameter DEFAULTINTERVAL = 1;

ClassMethod Reading() As %DynamicObject
{
	set reading = {"mode":(..#MODE), "asOf":(##class(FlightDeck.Vitals.Service).Now())}
	do reading.%Set("intervalSeconds", ..#DEFAULTINTERVAL, "number")
	set instruments = []
	set iter = ##class(FlightDeck.Vitals.Service).Snapshot().%GetIterator()
	while iter.%GetNext(, .vital) { do instruments.%Push(..FromVital(vital)) }
	do instruments.%Push(..Counter("processes", "Processes", "GET /v2/processes"))
	do instruments.%Push(..Counter("devices", "Devices", "GET /v2/devices"))
	set reading.instruments = instruments
	set reading.resources = ..Resources()
	set reading.dashboards = ..Dashboards()
	quit reading
}

/// The instance's own dashboards, shown under the cluster with the platform's own words.
/// <p>Where the platform states a condition ("Normal", "Trouble"), FlightDeck repeats it and does
/// not recompute it (research R4). Each block carries its reason when this session cannot read it,
/// so a missing block is explained rather than absent.
ClassMethod Dashboards() As %DynamicObject
{
	set out = {}
	set blocks = $listbuild(
		$listbuild("main", "GET /v2/monitor/dashboard/main", "System dashboard"),
		$listbuild("ecp", "GET /v2/monitor/dashboard/ecp", "ECP"),
		$listbuild("globalsAndRoutines", "GET /v2/monitor/dashboard/globals-and-routines", "Globals and routines"),
		$listbuild("systemUsage", "GET /v2/monitor/system-usage", "System usage"),
		$listbuild("licenseUsage", "GET /v2/monitor/license-usage", "License usage"))
	set ptr = 0
	while $listnext(blocks, ptr, block) {
		set id = $list(block, 1), operationId = $list(block, 2), label = $list(block, 3)
		set entry = {"label":(label)}
		if '##class(FlightDeck.Admin.Client).Has(operationId) {
			do entry.%Set("available", 0, "boolean")
			do entry.%Set("reason", ##class(FlightDeck.Admin.Client).UnavailableReason(operationId), "string")
			do out.%Set(id, entry)
			continue
		}
		set value = ##class(FlightDeck.Admin.Client).Get($piece(operationId, " ", 2, *), , .status, .raw)
		if (status '= 200) || '$isobject(value) {
			do entry.%Set("available", 0, "boolean")
			do entry.%Set("reason", ##class(FlightDeck.Admin.Client).ErrorText(value, raw), "string")
			do out.%Set(id, entry)
			continue
		}
		do entry.%Set("available", 1, "boolean")
		do entry.%Set("value", value)
		do out.%Set(id, entry)
	}
	quit out
}

/// A vital in the instrument shape. Availability and its reason come from the vital, which took them
/// from the capability map or from the platform's own answer; nothing here asks the version.
ClassMethod FromVital(vital As %DynamicObject) As %DynamicObject
{
	set available = vital.state '= "unavailable"
	set instrument = {"id":(vital.id), "label":(vital.label), "unit":"%"}
	do instrument.%Set("available", available, "boolean")
	do instrument.%Set("value", vital.value, $select(vital.value="":"null", 1:"number"))
	do instrument.%Set("band", $select(vital.state="ok":"normal", vital.state="unavailable":"normal", 1:vital.state), "string")
	do instrument.%Set("scope", vital.scope, $select(vital.scope="":"null", 1:"string"))
	do instrument.%Set("reason", vital.reason, $select(vital.reason="":"null", 1:"string"))
	do instrument.%Set("detail", $select(vital.%IsDefined("detail"):vital.detail, 1:""), $select(vital.%IsDefined("detail"):"string", 1:"null"))
	// Disk arrives through an asynchronous task: the state travels with the value so the screen can
	// say a refresh is in flight without ever removing the number (RN-FD-32).
	if vital.id = "disk" {
		set async = {"state":($select(''vital.pending:"Running", vital.state="unavailable":"Failed", 1:"Finished"))}
		do async.%Set("lastValueAt", vital.asOf, $select(vital.asOf="":"null", 1:"string"))
		do async.%Set("stale", ''vital.pending, "boolean")
		do async.%Set("message", vital.reason, $select(vital.reason="":"null", 1:"string"))
		set instrument.async = async
	}
	quit instrument
}

/// A count of what a list operation returns. Unavailable is reported with the map's own reason, and
/// the instrument keeps its place in the cluster (spec FR-021).
ClassMethod Counter(id As %String, label As %String, operationId As %String) As %DynamicObject
{
	set instrument = {"id":(id), "label":(label), "unit":""}
	do instrument.%Set("band", "normal", "string")
	do instrument.%Set("scope", "", "null")
	do instrument.%Set("detail", "", "null")
	if '##class(FlightDeck.Admin.Client).Has(operationId) {
		do instrument.%Set("available", 0, "boolean")
		do instrument.%Set("value", "", "null")
		do instrument.%Set("reason", ##class(FlightDeck.Admin.Client).UnavailableReason(operationId), "string")
		quit instrument
	}
	set path = $piece(operationId, " ", 2, *)
	set rows = ##class(FlightDeck.Admin.Client).Get(path, {"maxRows":"1000"}, .status, .raw)
	if (status '= 200) || '$isobject(rows) {
		do instrument.%Set("available", 0, "boolean")
		do instrument.%Set("value", "", "null")
		do instrument.%Set("reason", ##class(FlightDeck.Admin.Client).ErrorText(rows, raw), "string")
		quit instrument
	}
	do instrument.%Set("available", 1, "boolean")
	do instrument.%Set("value", rows.%Size(), "number")
	do instrument.%Set("reason", "", "null")
	quit instrument
}

/// The seize table (GET /v2/monitor/dashboard/system-resources): resource contention, reported as a
/// table under the cluster and not as a fourth instrument. The specification declares no meaning for
/// these counters, so FlightDeck shows them and invents no threshold (research R3).
ClassMethod Resources() As %DynamicArray
{
	set out = []
	quit:'##class(FlightDeck.Admin.Client).Has("GET /v2/monitor/dashboard/system-resources") out
	set rows = ##class(FlightDeck.Admin.Client).Get("/v2/monitor/dashboard/system-resources", , .status, .raw)
	quit:(status'=200)||'$isobject(rows) out
	set iter = rows.%GetIterator()
	while iter.%GetNext(, .row) {
		continue:'$isobject(row)
		continue:$select(row.%IsDefined("Name"):row.Name, 1:"")=""
		do out.%Push(row)
	}
	quit out
}

}
