/// Feature 005: a file that changes under the reader (spec FR-014, FR-015).
Class FlightDeck.Test.LogReaderRotation Extends %UnitTest.TestCase
{

Parameter FILE = "/tmp/fd-test-rotation.log";

Method Write(lines As %Integer, from As %Integer = 1) As %Status
{
	set stream = ##class(%Stream.FileCharacter).%New()
	do stream.LinkToFile(..#FILE)
	do stream.Clear()
	for i = from:1:(from + lines - 1) { do stream.WriteLine("line " _ i) }
	quit stream.%Save()
}

Method OnAfterAllTests() As %Status
{
	do ##class(%File).Delete(..#FILE)
	quit $$$OK
}

Method TestAGrowingFileDoesNotShiftThePagesAlreadyServed()
{
	do ..Write(200)
	set first = ##class(FlightDeck.Logs.Reader).Page(..#FILE, , , 5)
	set newest = first.lines.%Get(0)
	// Something appends while the reader is paging.
	set stream = ##class(%Stream.FileCharacter).%New()
	do stream.LinkToFile(..#FILE)
	do stream.MoveToEnd()
	for i = 201:1:220 { do stream.WriteLine("line " _ i) }
	do stream.%Save()
	set second = ##class(FlightDeck.Logs.Reader).Page(..#FILE, first.cursor, , 5)
	do $$$AssertEquals(second.changed, "", "growth is not a change under the reader")
	set iter = second.lines.%GetIterator()
	while iter.%GetNext(, .line) { do $$$AssertNotEquals(line, newest, "the second page does not repeat the first") }
}

Method TestATruncatedFileStopsTheReader()
{
	do ..Write(200)
	set first = ##class(FlightDeck.Logs.Reader).Page(..#FILE, , , 5)
	// Rotation: the file is replaced by a shorter one.
	do ..Write(5, 1000)
	set second = ##class(FlightDeck.Logs.Reader).Page(..#FILE, first.cursor, , 5)
	do $$$AssertNotEquals(second.changed, "", "the reader reports the change")
	do $$$AssertTrue(second.changed [ "rotated", "and says what happened: "_second.changed)
	do $$$AssertEquals(second.lines.%Size(), 0, "it returns nothing rather than mixing two files")
}

}
