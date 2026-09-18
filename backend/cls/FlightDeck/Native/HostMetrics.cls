/// Native provider for host CPU and host memory (Constitution I v2.0.0 gap, research R8, FR-031a).
/// The SysAdmin API v2 reports only IRIS-internal counters and IRIS shared memory.
/// <p>Reads /proc/stat and /proc/meminfo only. In a container these describe the Docker host kernel,
/// not cgroup limits (<method>Scope</method>). Callers must check Use on %Admin_Operate first.
/// <p><b>The reading and the parsing are Embedded Python.</b> Opening a file under /proc and pulling
/// numbers out of its text is filesystem and string work, which is what Python is for; ObjectScript
/// keeps what is its own — the %Status contract, the session-held previous sample, and the arithmetic
/// whose rounding the published values depend on. This is the same reading as before, in the language
/// that suits it, not a feature added to use a language: the ObjectScript version needed a sequential
/// device opened by hand because %Stream.FileCharacter reads nothing from procfs, where a file
/// reports size 0. Python's open() has no such problem, and that workaround is gone.
/// <p>No version is tested anywhere here (Constitution III). Embedded Python needs IRIS 2021.2 or
/// later, far below the 2026.1 FlightDeck itself requires, so an instance that can run this portal
/// has it; and if the Python runtime fails anyway, every entry point degrades through the status this
/// class already returned, so the screen states a reason instead of breaking.
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
	set percent = ""
	set asOf = ""
	set sc = ..ParseMeminfo(..ReadMeminfo(), .percent)
	quit:$$$ISERR(sc) sc
	set asOf = $translate($zdatetime($ztimestamp, 3, 1, 3), " ", "T") _ "Z"
	quit $$$OK
}

/// Total and available kilobytes from /proc/meminfo text, as "total available", or "" when the text
/// carries neither. The percentage stays in ObjectScript below, because $normalize is what the
/// published values have always been rounded with.
ClassMethod ParseMeminfo(text As %String, Output percent As %Numeric) As %Status
{
	set percent = ""
	set pair = ..Guarded("ParseMeminfoPy", text)
	if pair = "" quit $$$ERROR($$$GeneralError, ..#UNREADABLE)
	set total = $piece(pair, " ", 1), available = $piece(pair, " ", 2)
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
	set pair = ..Guarded("ParseCPULinePy", line)
	if pair = "" quit $$$ERROR($$$GeneralError, ..#UNREADABLE)
	set busy = +$piece(pair, " ", 1), total = +$piece(pair, " ", 2)
	quit $$$OK
}

ClassMethod ReadCPUSample(Output busy As %Integer, Output total As %Integer) As %Status
{
	quit ..ParseCPULine(..ReadStatLine(), .busy, .total)
}

/// "Docker host kernel" inside a container, otherwise "".
ClassMethod Scope() As %String
{
	quit $select(..Guarded("InContainerPy"):"Docker host kernel", 1:"")
}

/// Calls one of the Python methods below and answers "" if the call itself cannot be made.
/// <p>The Python methods already answer "" for a missing file or a line they cannot read. This
/// catches the other case — a Python runtime that is not usable at all — so that an instance without
/// Embedded Python degrades exactly like one whose /proc cannot be read, through the same status and
/// the same reason, rather than raising an error into a screen (rule: never break the screen).
ClassMethod Guarded(name As %String, argument As %String) As %String [ Private ]
{
	set answer = ""
	try {
		// $data, not a default: two of these methods take no argument at all, and calling one with a
		// spare argument raises, which this catch would then swallow, leaving every reading empty
		// and looking exactly like an instance without Embedded Python.
		if $data(argument) {
			set answer = $classmethod($classname(), name, argument)
		} else {
			set answer = $classmethod($classname(), name)
		}
	} catch {
		set answer = ""
	}
	quit answer
}

ClassMethod ReadStatLine() As %String [ Private ]
{
	quit ..Guarded("ReadStatLinePy")
}

ClassMethod ReadMeminfo() As %String [ Private ]
{
	quit ..Guarded("ReadMeminfoPy")
}

// --- Embedded Python: the file reading and the text parsing ----------------------------------
//
// Each of these answers "" (or 0) on any failure: a missing file, a permission error, a line that
// is not shaped as expected, or the Python runtime itself being unusable. The ObjectScript above
// turns that into the same %Status it has always returned, so a failure here degrades the vital with
// its reason and never reaches the screen as an error.

/// The first line of /proc/stat, or "" if it cannot be read.
ClassMethod ReadStatLinePy() As %String [ Language = python ]
{
    try:
        with open("/proc/stat", "r") as handle:
            return handle.readline().strip()
    except Exception:
        return ""
}

/// The whole of /proc/meminfo, or "" if it cannot be read. Small and bounded: a few kilobytes.
ClassMethod ReadMeminfoPy() As %String [ Language = python ]
{
    try:
        with open("/proc/meminfo", "r") as handle:
            return handle.read()
    except Exception:
        return ""
}

/// "busy total" from an aggregate cpu line, or "" when the line is not one.
/// <p>The eight fields counted are user, nice, system, idle, iowait, irq, softirq and steal; idle and
/// iowait are the two that are not busy. A line with fewer fields, or a non-numeric one, is not a
/// reading — it answers "" rather than a number built out of part of it.
ClassMethod ParseCPULinePy(line As %String) As %String [ Language = python ]
{
    try:
        fields = (line or "").split()
        if len(fields) < 9 or fields[0] != "cpu":
            return ""
        values = [int(field) for field in fields[1:9]]
    except (ValueError, TypeError):
        return ""
    total = sum(values)
    idle = values[3] + values[4]
    return "%d %d" % (total - idle, total)
}

/// "total available" in kilobytes from /proc/meminfo text, or "" when either is absent.
ClassMethod ParseMeminfoPy(text As %String) As %String [ Language = python ]
{
    wanted = {"MemTotal": None, "MemAvailable": None}
    for line in (text or "").splitlines():
        key, separator, rest = line.partition(":")
        if not separator or key not in wanted:
            continue
        fields = rest.split()
        if not fields:
            continue
        try:
            wanted[key] = int(fields[0])
        except ValueError:
            return ""
    if wanted["MemTotal"] is None or wanted["MemAvailable"] is None:
        return ""
    return "%d %d" % (wanted["MemTotal"], wanted["MemAvailable"])
}

/// Whether this instance is running in a container.
ClassMethod InContainerPy() As %Boolean [ Language = python ]
{
    import os
    try:
        if os.path.exists("/.dockerenv"):
            return 1
        with open("/proc/1/cgroup", "r") as handle:
            cgroup = handle.read()
        return 1 if ("docker" in cgroup or "containerd" in cgroup or "kubepods" in cgroup) else 0
    except Exception:
        return 0
}

}
