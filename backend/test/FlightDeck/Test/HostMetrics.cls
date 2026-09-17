Class FlightDeck.Test.HostMetrics Extends %UnitTest.TestCase
{

Method TestParseCPULine()
{
	set sc = ##class(FlightDeck.Native.HostMetrics).ParseCPULine("cpu  100 0 50 800 50 0 0 0 0 0", .busy, .total)
	do $$$AssertStatusOK(sc)
	do $$$AssertEquals(total, 1000)
	do $$$AssertEquals(busy, 150, "busy excludes idle and iowait")
	do $$$AssertStatusNotOK(##class(FlightDeck.Native.HostMetrics).ParseCPULine("intr 1 2 3", .b, .t))
}

Method TestParseMeminfo()
{
	set text = "MemTotal:       1000 kB"_$char(10)_"MemFree:         100 kB"_$char(10)_"MemAvailable:    250 kB"_$char(10)
	do $$$AssertStatusOK(##class(FlightDeck.Native.HostMetrics).ParseMeminfo(text, .percent))
	do $$$AssertEquals(percent, 75)
	do $$$AssertStatusNotOK(##class(FlightDeck.Native.HostMetrics).ParseMeminfo("nothing", .p))
}

Method TestLiveReadingsAreInRange()
{
	do $$$AssertStatusOK(##class(FlightDeck.Native.HostMetrics).CPU(.cpu, .asOf))
	do $$$AssertTrue((cpu >= 0) && (cpu <= 100), "cpu "_cpu)
	do $$$AssertStatusOK(##class(FlightDeck.Native.HostMetrics).CPU(.cpu2))
	do $$$AssertStatusOK(##class(FlightDeck.Native.HostMetrics).Memory(.mem, .asOf))
	do $$$AssertTrue((mem > 0) && (mem <= 100), "memory "_mem)
}

}
