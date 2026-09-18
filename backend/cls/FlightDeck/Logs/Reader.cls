/// Backwards paged reading of one log file (RN-FD-25, feature 005 spec FR-012 to FR-015).
/// <p>The rule this class exists to keep: <b>the whole file is never read, at any size</b>. A page
/// seeks to an offset near the end, reads one bounded window, and returns the lines it found there.
/// Callers cannot opt out of the bound, because they never see the stream.
/// <p>Probed on IRIS 2026.2 (verification/README.md): %Stream.FileCharacter.MoveTo followed by a
/// short Read returns that slice and nothing before it, which is what makes this implementable.
Class FlightDeck.Logs.Reader [ Abstract ]
{

/// Bytes read per page. Large enough that a page is usually full, small enough that a page of a
/// 10 GB file costs the same as a page of a 10 KB one.
Parameter WINDOW = 65536;

/// Most lines one page returns, whatever the window held.
Parameter LINES = 200;

/// Reads one page, newest lines first.
/// <p><var>cursor</var> is "" for the first page, and afterwards the value this method returned.
/// It carries the file's size and modification time as they were on the first page, so a file that
/// grows underneath does not shift the pages already served (spec FR-015), and a file that shrinks
/// or is replaced is reported rather than silently mixed with its successor (spec FR-014).
ClassMethod Page(file As %String, cursor As %String = "", window As %Integer = 0, lines As %Integer = 0) As %DynamicObject
{
	set window = $select(window>0:window, 1:..#WINDOW)
	set lines = $select(lines>0:lines, 1:..#LINES)
	set answer = {"lines":[], "cursor":"", "exhausted":false, "changed":"", "available":true, "reason":""}
	if '##class(%File).Exists(file) {
		do answer.%Set("available", 0, "boolean")
		set answer.reason = "The instance has not written " _ file _ "."
		quit answer
	}
	set size = ##class(%File).GetFileSize(file)
	set modified = ##class(%File).GetFileDateModified(file)
	if cursor = "" {
		set start = size, firstSize = size, firstModified = modified
	} else {
		set start = +$piece(cursor, "|", 1), firstSize = +$piece(cursor, "|", 2), firstModified = $piece(cursor, "|", 3)
	}
	// The file moved backwards: it was rotated or truncated. Reading on would mix two files.
	if (size < firstSize) || ((firstModified '= "") && (modified < firstModified)) {
		set answer.changed = "The file changed while it was being read (it was rotated or truncated). Start again to read the current file."
		quit answer
	}
	if start <= 0 {
		do answer.%Set("exhausted", 1, "boolean")
		quit answer
	}
	set from = start - window
	set partial = 1
	if from < 0 set from = 0, partial = 0
	set stream = ##class(%Stream.FileCharacter).%New()
	set sc = stream.LinkToFile(file)
	if $$$ISERR(sc) {
		do answer.%Set("available", 0, "boolean")
		set answer.reason = $system.Status.GetErrorText(sc)
		quit answer
	}
	if from > 0 {
		set sc = stream.MoveTo(from + 1)
		if $$$ISERR(sc) {
			do answer.%Set("available", 0, "boolean")
			set answer.reason = $system.Status.GetErrorText(sc)
			quit answer
		}
	}
	set text = stream.Read(start - from)
	do stream.%Close()
	// The first line of a window is usually the tail of a line that began in the page before it.
	// It is dropped here and returned whole by that page, so no line is reported twice or in half.
	set found = [], count = $length(text, $char(10)), oldest = count + 1
	for i = count:-1:1 {
		continue:((i=1)&&partial)
		set line = $zstrip($piece(text, $char(10), i), ">", $char(13))
		set oldest = i
		continue:line=""
		do found.%Push(line)
		quit:found.%Size()>=lines
	}
	set answer.lines = found
	// Where the page stopped, in characters of the text actually read. Reconstructing this from the
	// returned lines would undercount: the values are stripped of CR, and the separator is two
	// characters, so the pages would overlap by a line every window (caught by LogReader).
	if found.%Size() >= lines, oldest > 1 {
		set consumed = $length($piece(text, $char(10), oldest, *)) + 1
		set next = start - consumed
	} else {
		set next = from
	}
	set:next<0 next = 0
	do answer.%Set("exhausted", next<=0, "boolean")
	set answer.cursor = next _ "|" _ firstSize _ "|" _ firstModified
	quit answer
}

}
