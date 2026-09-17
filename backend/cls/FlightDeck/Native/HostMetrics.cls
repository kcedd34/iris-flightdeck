/// Native provider for host CPU and host memory (Constitution I v2.0.0 gap, research R8, FR-031a).
/// The SysAdmin API v2 reports only IRIS-internal counters and IRIS shared memory.
/// <p>Reads /proc/stat and /proc/meminfo only. In a container these describe the Docker host kernel,
/// not cgroup limits (<method>Scope</method>). Callers must check Use on %Admin_Operate first.
Class FlightDeck.Native.HostMetrics [ Abstract ]
{

Parameter UNREADABLE = "Host metrics are not readable on this platform.";

/// Host CPU utilization in percent between the previous sample (kept in the caller's %session) and
/// now. Without a usable previous sample, takes two readings one second apart.
ClassMethod CPU(Output percent As %Numeric, Output asOf As %String) As %Status
{
	set percent = "", asOf = ""
	set sc = ..ReadCPUSample(.busy, .total)
	quit:$$$ISERR(sc) sc
	set now = $zdatetime($ztimestamp, 3, 1, 3)
	set previous = ""
	if $data(%session)#2, $isobject(%session) {
		set previous = $get(%session.Data("fd.host.cpu"))
	}
	set age = $select(previous="":0, 1:$system.SQL.Functions.DATEDIFF("ms", $list(previous, 3), now))
	// A sample under one second old gives a noisy delta: return the last computed value instead.
	if (previous '= ""), (age < 1000), ($listget(previous, 4) '= "") {
		set percent = $list(previous, 4), asOf = $list(previous, 5)
		quit $$$OK
	}
	if (previous = "") || (age < 1000) || ($list(previous, 2) >= total) {
		hang 1
		set previous = $listbuild(busy, total, now)
		set sc = ..ReadCPUSample(.busy, .total)
		quit:$$$ISERR(sc) sc
		set now = $zdatetime($ztimestamp, 3, 1, 3)
	}
	set deltaTotal = total - $list(previous, 2)
	set deltaBusy = busy - $list(previous, 1)
	set percent = $select(deltaTotal>0:$normalize(100 * deltaBusy / deltaTotal, 1), 1:0)
	set:percent<0 percent = 0
	set:percent>100 percent = 100
	set asOf = $translate(now, " ", "T") _ "Z"
	if $data(%session)#2, $isobject(%session) {
		set %session.Data("fd.host.cpu") = $listbuild(busy, total, now, percent, asOf)
	}
	quit $$$OK
}

/// Host memory in use: (MemTotal - MemAvailable) / MemTotal.
ClassMethod Memory(Output percent As %Numeric, Output asOf As %String) As %Status
{
	set percent = "", asOf = ""
	set sc = ..ReadFile("/proc/meminfo", .text)
	quit:$$$ISERR(sc) sc
	set sc = ..ParseMeminfo(text, .percent)
	quit:$$$ISERR(sc) sc
	set asOf = $translate($zdatetime($ztimestamp, 3, 1, 3), " ", "T") _ "Z"
	quit $$$OK
}

ClassMethod ParseMeminfo(text As %String, Output percent As %Numeric) As %Status
{
	set percent = "", total = "", available = ""
	for i=1:1:$length(text, $char(10)) {
		set line = $piece(text, $char(10), i)
		set key = $piece(line, ":", 1)
		set value = +$zstrip($piece(line, ":", 2), "<>W")
		set:key="MemTotal" total = value
		set:key="MemAvailable" available = value
	}
	if (total = "") || (available = "") || (total <= 0) {
		quit $$$ERROR($$$GeneralError, ..#UNREADABLE)
	}
	set percent = $normalize(100 * (total - available) / total, 1)
	quit $$$OK
}

/// Parses the aggregate "cpu" line: user nice system idle iowait irq softirq steal.
ClassMethod ParseCPULine(line As %String, Output busy As %Integer, Output total As %Integer) As %Status
{
	set busy = 0, total = 0
	set fields = $zstrip(line, "<=>W")
	if $piece(fields, " ", 1) '= "cpu" quit $$$ERROR($$$GeneralError, ..#UNREADABLE)
	for i=2:1:9 {
		set total = total + $piece(fields, " ", i)
	}
	set idle = $piece(fields, " ", 5) + $piece(fields, " ", 6)
	set busy = total - idle
	quit $$$OK
}

ClassMethod ReadCPUSample(Output busy As %Integer, Output total As %Integer) As %Status
{
	set sc = ..ReadFile("/proc/stat", .text)
	quit:$$$ISERR(sc) sc
	quit ..ParseCPULine($piece(text, $char(10), 1), .busy, .total)
}

/// "Docker host kernel" inside a container, otherwise "".
ClassMethod Scope() As %String
{
	if ##class(%File).Exists("/.dockerenv") quit "Docker host kernel"
	if ..ReadFile("/proc/1/cgroup", .text), (text [ "docker") || (text [ "containerd") || (text [ "kubepods") quit "Docker host kernel"
	quit ""
}

/// Reads a small text file line by line through a sequential device. %Stream.FileCharacter cannot
/// be used: procfs files report size 0, so a stream reads nothing.
ClassMethod ReadFile(path As %String, Output text As %String) As %Status
{
	set text = ""
	if $system.Version.GetOS() '= "UNIX" quit $$$ERROR($$$GeneralError, ..#UNREADABLE)
	set io = $io
	set sc = $$$OK
	set opened = 0
	try {
		open path:("RS"):2
		if '$test $$$ThrowStatus($$$ERROR($$$GeneralError, ..#UNREADABLE))
		set opened = 1
		use path
		for i=1:1:4096 {
			read line
			set text = text _ line _ $char(10)
		}
	} catch ex {
		if ex.Name '= "<ENDOFFILE>" set sc = $$$ERROR($$$GeneralError, ..#UNREADABLE)
	}
	if opened close path
	use io
	if text = "" set sc = $$$ERROR($$$GeneralError, ..#UNREADABLE)
	quit sc
}

}
