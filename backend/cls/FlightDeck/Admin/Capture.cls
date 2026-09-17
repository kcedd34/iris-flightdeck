/// Output capture for in-process calls to the official API (research R4, verification/README.md). Uses I/O redirection on the current
/// (principal) device instead of switching to a file device, because some official handlers switch
/// devices internally and return to $PRINCIPAL, which would send their output straight to the HTTP
/// response (found with GET /v2/journal/files in a web request).
Class FlightDeck.Admin.Capture [ Abstract ]
{

/// Starts capturing. Returns the state needed by <method>Stop</method>.
ClassMethod Start() As %List
{
	kill ^||FlightDeck.Capture
	set state = $listbuild(##class(%Library.Device).GetMnemonicRoutine(), ##class(%Library.Device).ReDirectIO(), $io)
	// The official handlers run in %SYS. The installer deploys this class to %SYS as well
	// (FlightDeck.Install.Installer.DeployCapture), so the mnemonic routine resolves from %SYS and
	// from the namespace FlightDeck is installed in alike.
	use $io::("^"_$zname)
	do ##class(%Library.Device).ReDirectIO(1)
	quit state
}

/// Stops capturing, restores the device, and returns the captured text (max 1 MB).
ClassMethod Stop(state As %List) As %String
{
	do ##class(%Library.Device).ReDirectIO(0)
	set device = $list(state, 3)
	set mnemonic = $list(state, 1)
	if mnemonic '= "" {
		use device::("^"_mnemonic)
	} else {
		use device
	}
	do ##class(%Library.Device).ReDirectIO($list(state, 2))
	set text = ""
	set i = ""
	for {
		set i = $order(^||FlightDeck.Capture(i), 1, chunk)
		quit:i=""
		quit:$length(text)>1048576
		set text = text _ chunk
	}
	kill ^||FlightDeck.Capture
	quit text
}

/// Mnemonic entry points called by the redirected device.
ClassMethod Redirects() [ Internal, ProcedureBlock = 0 ]
{
wstr(s)	set ^||FlightDeck.Capture($increment(^||FlightDeck.Capture)) = s
	quit
wchr(c)	set ^||FlightDeck.Capture($increment(^||FlightDeck.Capture)) = $char(c)
	quit
wnl	set ^||FlightDeck.Capture($increment(^||FlightDeck.Capture)) = $char(13, 10)
	quit
wff	quit
wtab(n)	quit
rstr(len, time)	quit ""
rchr(time)	quit ""
}

}
