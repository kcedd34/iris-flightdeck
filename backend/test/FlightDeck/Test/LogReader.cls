/// Feature 005: the backwards paged reader. These tests exist to make "the whole file is never read"
/// checkable rather than aspirational (RN-FD-25, spec FR-012, FR-013).
Class FlightDeck.Test.LogReader Extends %UnitTest.TestCase
{

Parameter FILE = "/tmp/fd-test-reader.log";

Parameter LINECOUNT = 5000;

Method OnBeforeAllTests() As %Status
{
	set stream = ##class(%Stream.FileCharacter).%New()
	do stream.LinkToFile(..#FILE)
	for i = 1:1:..#LINECOUNT { do stream.WriteLine("line " _ i _ " " _ $justify("", 40)) }
	quit stream.%Save()
}

Method OnAfterAllTests() As %Status
{
	do ##class(%File).Delete(..#FILE)
	quit $$$OK
}

Method TestFirstPageIsTheTail()
{
	set page = ##class(FlightDeck.Logs.Reader).Page(..#FILE, , , 10)
	do $$$AssertTrue(page.available, "the file is readable")
	do $$$AssertEquals(page.lines.%Size(), 10, "the line cap holds")
	// Newest first: the last line of the file is the first line of the page.
	do $$$AssertTrue(page.lines.%Get(0) [ ("line " _ ..#LINECOUNT), "the newest line comes first: "_page.lines.%Get(0))
}

Method TestNextPageIsOlderAndDoesNotRepeat()
{
	set first = ##class(FlightDeck.Logs.Reader).Page(..#FILE, , , 10)
	set second = ##class(FlightDeck.Logs.Reader).Page(..#FILE, first.cursor, , 10)
	do $$$AssertEquals(second.lines.%Size(), 10)
	// The partial first line of a window belongs to the page before it, and is returned once.
	set overlap = 0
	set a = first.lines.%GetIterator()
	while a.%GetNext(, .lineA) {
		set b = second.lines.%GetIterator()
		while b.%GetNext(, .lineB) { if lineA = lineB set overlap = overlap + 1 }
	}
	do $$$AssertEquals(overlap, 0, "no line is served by two pages")
	do $$$AssertTrue(second.lines.%Get(0) '[ ("line " _ ..#LINECOUNT), "the second page is older")
}

Method TestNoPageReadsMoreThanItsWindow()
{
	// The rule that cannot be retrofitted: a page of a large file costs the same as a page of a
	// small one. A window of 512 bytes cannot return more than 512 bytes of lines.
	set page = ##class(FlightDeck.Logs.Reader).Page(..#FILE, , 512, 1000)
	set total = 0
	set iter = page.lines.%GetIterator()
	while iter.%GetNext(, .line) { set total = total + $length(line) + 1 }
	do $$$AssertTrue(total <= 512, "a page never returns more than its window: "_total)
}

Method TestWalkingToTheStartTerminates()
{
	set cursor = "", pages = 0, lines = 0
	for {
		set page = ##class(FlightDeck.Logs.Reader).Page(..#FILE, cursor, 4096, 50)
		set pages = pages + 1
		set lines = lines + page.lines.%Size()
		set cursor = page.cursor
		quit:page.exhausted
		quit:pages>500
	}
	do $$$AssertTrue(pages < 500, "the walk terminates: "_pages_" pages")
	do $$$AssertTrue(lines > 0, "it read something: "_lines)
}

Method TestAMissingFileIsUnavailableNotEmpty()
{
	set page = ##class(FlightDeck.Logs.Reader).Page("/tmp/fd-test-does-not-exist.log")
	do $$$AssertNotTrue(page.available, "a missing file is unavailable")
	do $$$AssertTrue(page.reason [ "has not written", "and says so: "_page.reason)
}

}
