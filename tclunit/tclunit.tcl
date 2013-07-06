#-----------------------------------------------------------
#
#  tclunit
#
#  Tclunit will execute a single test file, or run
#  all tests in a directory using tcltest's runAllTests
#  procedure.  Test output is captured, parsed, and
#  made available for e.g. being presented in a GUI.
#
#  [the remainder of Bob's initial comment still exists in
#  tclunit_gui.tcl, please see there]
#
#-----------------------------------------------------------
#
#  The original tclunit is now splitted into the basic
#  functionality and the GUI code. The GUI code can be found
#  in tclunit_gui.tcl now.
#  The functionality has been touched and extended at
#  various places to better fit into the new architecture
#  and provide the possibility to further extend it. It is now
#  a proper package and moved in its own namespace.
#
#  Matthias Kraft
#  June 12, 2012
#
#-----------------------------------------------------------

package require Tcl 8.5

namespace eval tclunit {
    namespace export configure run_tests stop_tests

    # Capturing Test Output array
    variable cto

    # Array with runtime configuration
    variable rt
    set rt(interp)	[info nameofexecutable]
    # Run tests with verbose options so we can parse the output
    set rt(verbosity)	{body pass skip start error}
    set rt(testconfig)	[list -verbose $rt(verbosity)]

    # Array with callbacks for events
    variable cbs
    array set cbs {
	init		noop
	property	noop
	suite		noop
	skipped		noop
	start		noop
	passed		noop
	failed		noop
	error		noop
	status		noop
	total		noop
    }

    # List with known properties from tcltest (2.2.10 / 2.3.4)
    variable known_props {}
    lappend known_props \
	"Tests running in interp:" \
	"Tests located in:" \
	"Tests running in:" \
	"Temporary files stored in" \
	"Test files sourced into current interpreter" \
	"Test files run in separate interpreters" \
	"Skipping tests that match:" \
	"Running tests that match:" \
	"Skipping test files that match:" \
	"Only running test files that match:"

    # Array with the tcltest begin and end timestamps prefix
    variable timeprefix
    array set timeprefix {
	start	"Tests began at"
	end	"Tests ended at"
    }
}

#-----------------------------------------------------------
#  tclunit::noop
#
#  Description:
#    Default callback. Eats all arguments and does nothing.
#
#  Arguments:
#    ...
#
#  Side Effects:
#    None.
#-----------------------------------------------------------
proc tclunit::noop {args} {}

#-----------------------------------------------------------
#  tclunit::configure
#
#  Description:
#    Configuration of the tclunit module. Right now the
#    interpreter for running the tests can be configured. And
#    listener scripts can be bound to a couple of events.
#
#  Event tags:
#    init - called just before running the tests
#    suite - called when runAllTests started a new test suite
#	filename - the script has to take one arg, a filename
#    skipped - called if a test was skipped
#	filename - the suite this test belongs to
#	testname - the name of the skipped test
#	reason - the name of the tcltest constraint
#    start - called when a new test started
#	filename - the suite this test belongs to
#	testname - the name of the started test
#    passed - called when a test passed
#	filename - the suite this test belongs to
#	testname - the name of the passed test
#    failed - called when a test failed
#	filename - the suite this test belongs to
#	testname - the name of the failing test
#	report - the usual tcltest output
#    status - called whenever a test has been finished
#	filename - the currently running test suite
#	passed - the number of passed tests of the suite so far
#	skipped - the number of skipped tests
#	failed - the number of failed tests
#    total - called just after all tests finished
#	passed - the number of all passed tests
#	skipped - the number of all skipped tests
#	failed - the number of all failed tests
#	time - time all testing took in ms
#    property - called if one of the known tcltest messages appears
#	name - name of the property
#	value - and its value
#    error - not yet implemented
#
#  Arguments:
#    event <tag> <script> - register <script> for event <tag>
#    interp <path to interpreter> - interpreter to use for testing
#    tcltest <list of tcltest::configure options>
#	 - drops -verbose, -outfile and -errfile, as they are needed by tclunit
#    reset - resets everything to its defaults upon encounter, stops processing
#	 of any further arguments and returns an empty list
#
#  Side Effects:
#    Configuration changes.
#-----------------------------------------------------------
proc tclunit::configure {args} {
    variable cbs
    variable rt

    if {[llength $args] == 0} {
	# full configuration introspection
	foreach tag [lsort [array names cbs]] {
	    lappend args event $tag {}
	}
	lappend args interp {}
	lappend args tcltest {}
    }

    set result {}

    while {[llength $args]} {
	set args [lassign $args cmd]
	switch -- $cmd {
	    event {
		set args [lassign $args tag script]
		if {$tag ni [array names cbs]} {
		    return -code error "unknown event $tag, must be one of: [join [lsort [array names cbs]] {, }]"
		}
		if {$script eq ""} {
		    lappend result [list event $tag $cbs($tag)]
		} else {
		    set cbs($tag) $script
		}
	    }
	    interp {
		set args [lassign $args interp]
		if {$interp eq ""} {
		    lappend result [list interp $rt(interp)]
		} else {
		    set rt(interp) $interp
		}
	    }
	    tcltest {
		set args [lassign $args testconfig]
		if {$testconfig eq ""} {
		    # TODO: introspect tcltest settings in interp?
		    lappend result [list tcltest $rt(testconfig)]
		} elseif {[catch {array set FilterConfig $testconfig} msg]} {
		    return -code error "unable to filter tcltest configuration: $msg"
		} else {
		    # Almost everything might be configured, but not ...
		    set FilterConfig(-verbose) $rt(verbosity)
		    array unset FilterConfig -outfile
		    array unset FilterConfig -errfile
		    set rt(testconfig) [array get FilterConfig]
		}
	    }
	    reset {
		foreach tag [array names cbs] {
		    set cbs($tag) noop
		}
		set rt(interp) [info nameofexecutable]
		set rt(testconfig) [list -verbose $rt(verbosity)]
		set result {}
		break
	    }
	    default {
		return -code error "unknown command $cmd, must be event,\
				    interp, tcltest or reset"
	    }
	}
    }
    return $result
}

#-----------------------------------------------------------
#  tclunit::init_for_tests
#
#  Description:
#    Initializes variables for running test suite.
#
#  Arguments
#    none
#
#  Side Effects
#    Modified global env() array.
#    Sets initial values for capturing test output
#    Call configured init-callback
#
#-----------------------------------------------------------
proc tclunit::init_for_tests {} {
    variable cto
    variable cbs

    #  Initialize Capturing Test Output or "cto" array
    array unset cto
    array set cto {
	capturing 0
	filename ""
	passed 0
	skipped 0
	failed 0
	totalpassed 0
	totalskipped 0
	totalfailed 0
	testName ""
	result ""
    }

    # Call foreign initialization hook
    {*}$cbs(init)
}

#-----------------------------------------------------------
#  tclunit::run_all_tests
#
#  Description:
#    Creates a test script for running all tests in the
#    current working directory. Then runs the tests.
#
#  Arguments:
#    testdirectory - the directory with all the test files
#
#  Side Effects:
#    runs all the tests in the directory
#-----------------------------------------------------------
proc tclunit::run_all_tests {testdirectory} {
    variable rt

    init_for_tests
    set testScript {
	set ::env(TCLTEST_OPTIONS) [list $rt(testconfig)]
	cd "$testdirectory"
	package require tcltest
	tcltest::runAllTests
	exit
    }
    set testScript [subst $testScript]
    set rt(testdirectory) $testdirectory
    set rt(phase) "start"
    do_run_tests $testScript
}

#-----------------------------------------------------------
#  tclunit::run_test_file
#
#  Description:
#    Creates a test script for running a single test file,
#    then runs the tests.
#
#  Arguments:
#    testfile  - file to be tested
#  Side effects:
#    runs the test file
#-----------------------------------------------------------
proc tclunit::run_test_file {testfile} {
    variable rt

    init_for_tests
    set testScript {
	set ::env(TCLTEST_OPTIONS) [list $rt(testconfig)]
	cd [file dirname "$testfile"]
	source "$testfile"
	exit
    }
    set testScript [subst $testScript]
    test_file_start [file tail $testfile]
    set rt(testdirectory) [file dirname $testfile]
    set rt(phase) "tests"
    do_run_tests $testScript
}

#-----------------------------------------------------------
#  tclunit::do_run_tests
#
#  Description:
#    Run configured interpreter and feed it the test script
#    written by run_all_tests or run_test_file. Set up a
#    fileevent reader to parse the output. Then wait for it
#    to finish.
#
#    Just for fun, capture clock time before and after
#    running the tests, so we can compute a test
#    velocity.
#
#  Arguments:
#    testScript   - script to feed to tclsh
#  Side Effects:
#    execs tclsh process
#    defines fileevent to parse the output
#    and hangs until the parser notifies us.
#-----------------------------------------------------------
proc tclunit::do_run_tests { testScript } {
    variable rt

    #  Set timers
    set rt(started_tests) [clock milliseconds]
    set rt(finished_tests) 0

    #  Exec a tcl shell to run the scripts
    set rt(pipe) [open [format "|%s" $rt(interp)] w+]
    fconfigure $rt(pipe) -blocking 0 -buffering line
    fileevent $rt(pipe) readable [namespace code [list capture_test_output $rt(pipe)]]

    #  Tell the shell what to do
    puts $rt(pipe) $testScript

    #  And wait for it to finish
    vwait [namespace which -variable rt](finished_tests)

    #  check the time
    set rt(finished_tests) [clock milliseconds]
}

#-----------------------------------------------------------
#  tclunit::capture_test_output
#
#  Description:
#    Parses the tcltest output stream, and decides
#    if a line represents a pass, fail, skip, or
#    failure.  In case of failures, we expect more
#    lines of test case results, so we capture those
#    until a global flag is reset.
#
#    When running all tests, file names are printed
#    so if the line is a file name, we save that.
#
#  Arguments:
#    chan - stdout channel of the tcltest process
#  Side Effects:
#    none
#-----------------------------------------------------------
proc tclunit::capture_test_output {chan} {
    variable cto
    variable rt

    if {[catch {eof $chan} iors]} {
	puts stderr "!!!! while checking eof test output: $iors"
	puts stderr $::errorInfo

    } elseif {$iors} {
	# notify [do_run_tests] that we've completed
	set rt(finished_tests) 1
	close $chan
	return
    }

    # Read the line
    if {[catch {gets $chan line} iors]} {
	puts stderr "!!!! while reading test output: $iors"
	puts stderr $::errorInfo

    } elseif {$iors < 0} {
	# not enough input available
	return
    }
    # FIXME: just for debugging
    # puts stderr "${line}"

    # Now check which filter is handling this line...
    if { $cto(capturing) } {
	# We're saving up test results.
	test_failed_continue $line
	return
    }

    if {[string trim $line] eq ""} {
	# empty lines can be ignored beyond this point
	return
    }

    if {$rt(phase) eq "start"} {
	if {[test_properties $line]} {
	    # Logged a property line.
	    return
	} elseif {[started_tests $line]} {
	    # Logged tests started time stamp.
	    return
	}
    }

    if {$rt(phase) ne "end"} {
	if {[string match "*.test" $line]} {
	    # If the line is a file name then save it.
	    test_file_start $line
	    return
	} elseif {[string match "---- * start" $line]} {
	    # A new test case just started its execution.
	    test_started $line
	    return

	} elseif {[string match "++++ * PASSED" $line]} {
	    # A test case has passed.
	    test_passed $line
	    return

	} elseif {[string match "++++ * SKIPPED: *" $line]} {
	    # A test case has been skipped.
	    test_skipped $line
	    return

	} elseif {[string match "==== * FAILED" $line]} {
	    # A test case failed (starts capturing mode).
	    test_failed $line
	    return

	} elseif {[finished_tests $line]} {
	    # Logged tests finished time stamp.
	    return
	}
    }

    # TODO: also capture test file errors
    # TODO: also capture output not obviously belonging to any test
}

#-----------------------------------------------------------
#  tclunit::test_skipped
#
#  Description:
#    Count the test as skipped.
#
#  Arguments:
#    line  - text of line captured from tcltest output
#
#  Side Effects:
#    changes the test results variables
#-----------------------------------------------------------
proc tclunit::test_skipped {line} {
    variable cto
    variable cbs

    incr_test_counter "skipped"

    # send update
    if {[scan $line "++++ %s SKIPPED: %s" testName reason] < 2} {
	# fallback if testname contains whitespace
	regexp -- {^\+\+\+\+ (.+) SKIPPED: (.+)$} $line -> testName reason
    }
    {*}$cbs(skipped) $cto(filename) $testName $reason
}

#-----------------------------------------------------------
#  tclunit::test_started
#
#  Description:
#    Parse the test name from the line, and reset some of the
#    capture test ouput (cto) variables.
#
#  Arguments:
#    line  - text of line captured from tcltest output
#  Side Effects:
#    changes the capture test output (cto) variables
#-----------------------------------------------------------
proc tclunit::test_started {line} {
    variable cto
    variable cbs

    scan $line "---- %s start" testName
    set cto(testName) $testName
    set cto(result) ""
    set cto(capturing) 0

    # send update
    {*}$cbs(start) $cto(filename) $testName
}

#-----------------------------------------------------------
#  tclunit::test_passed
#
#  Description:
#    Count the test as passed.
#
#  Arguments:
#    line  - text of line captured from tcltest output
#
#  Side Effects:
#    changes the capture test output (cto) variables
#-----------------------------------------------------------
proc tclunit::test_passed {line} {
    variable cto
    variable cbs

    incr_test_counter "passed"

    #  update the GUI
    {*}$cbs(passed) $cto(filename) $cto(testName)
}

#-----------------------------------------------------------
#  tclunit::test_failed
#
#  Description:
#    Count the test as failed.
#    Start capturing tcltest output until we get
#    the second "FAILED" line.
#
#  Arguments:
#    line  - text of line captured from tcltest output
#  Side Effects:
#    changes the capture test output (cto) variables
#-----------------------------------------------------------
proc tclunit::test_failed {line} {
    variable cto

    incr_test_counter "failed"

    #  Start capturing failure results
    set cto(capturing) 1
    set cto(result) $line\n
}

#-----------------------------------------------------------
#  tclunit::test_failed_continue
#
#  Description:
#    Continue capturing failed test output, appending
#    it to this tests' results variable.  If we detect
#    the final line in the failed test output (with "FAILED")
#    then we stop the capture process.
#
#  Arguments:
#    line  - text of line captured from tcltest output
#
#  Side Effects:
#    changes the capture test output (cto) variables
#-----------------------------------------------------------
proc tclunit::test_failed_continue {line} {
    variable cbs
    variable cto

    append cto(result) ${line} \n

    #  Is this the last line in the failure log?
    if { $line eq "==== $cto(testName) FAILED" } {
	set cto(capturing) 0
	{*}$cbs(failed) $cto(filename) $cto(testName) $cto(result)
    }
}

#-----------------------------------------------------------
#  tclunit::test_file_start
#
#  Description:
#    Initializes the capture test output (cto) variables
#    for a new test file.
#
#  Arguments:
#    filename - name of test file (that is about to be run)
#
#  Side Effects:
#    changes the capture test output (cto) variables
#-----------------------------------------------------------
proc tclunit::test_file_start {filename} {
    variable cbs
    variable cto

    #  Save the filename (which is the only thing on the line)
    lappend cto(filenames) $filename
    set cto(filename) $filename

    #  Initialize the counters
    set cto(passed) 0
    set cto(skipped) 0
    set cto(failed) 0

    {*}$cbs(suite) $filename
}

#-----------------------------------------------------------
#  tclunit::incr_test_counter
#
#  Description:
#    Counts the test by incrementing the appropriate
#    counters in the capture test output (cto) variables.
#
#  Arguments:
#     resultType - one of "skipped", "passed", or "failed"
#
#  Side Effects:
#     changes the capture test output (cto) variables
#-----------------------------------------------------------
proc tclunit::incr_test_counter {resultType} {
    variable cto
    variable cbs

    incr cto($resultType)
    incr cto(total$resultType)

    #  Update the summary line
    {*}$cbs(status) $cto(filename) $cto(passed) $cto(skipped) $cto(failed)
}

#-----------------------------------------------------------
#  tclunit::run_tests
#
#  Description:
#    This proc decides whether to call run_all_tests, run_test_file or
#    read_testlog, then makes a nice summary of the tests.
#
#  Arguments:
#    path - either an existing directory, an existing test script (ending with
#	 .test) or a log file of a previous test run.
#
#  Side Effects
#    Pretty much everything happens.
#-----------------------------------------------------------
proc tclunit::run_tests {path} {
    variable cto
    variable cbs
    variable rt

    #  run the tests
    if {($path eq "") || ![file exists $path]} {
	return -code error "no test suite at '$path'"
    }

    if {[file isdirectory $path]} {
	run_all_tests [file normalize $path]
    } elseif {[file extension $path] eq ".test"} {
	run_test_file [file normalize $path]
    } else {
	read_testlog [file normalize $path]
    }

    # Computing timing statistic
    if {[info exists cto(tests_started)] && ($cto(tests_started) ne "") &&
	[info exists cto(tests_finished)] && ($cto(tests_finished) ne "")} {
	set time_in_ms [expr {($cto(tests_finished) - $cto(tests_started)) * 1000}]
    }
    if {![info exists time_in_ms] || ($time_in_ms <= 1000)} {
	set time_in_ms [expr {$rt(finished_tests) - $rt(started_tests)}]
    }

    # send final statistics
    {*}$cbs(total) $cto(totalpassed) $cto(totalskipped) $cto(totalfailed) $time_in_ms
}

#-----------------------------------------------------------
#  tclunit::stop_tests
#
#  Description:
#    This procedure terminates the running test process by
#    closing the pipe and setting the vwait flag.
#
#  Arguments:
#    none
#  Side Effects
#    Pretty much everything stops.
#-----------------------------------------------------------
proc tclunit::stop_tests {} {
    variable rt

    close $rt(pipe)
    set rt(finished_tests) 1
}

#-----------------------------------------------------------
#  tclunit::read_testlog
#
#  Description:
#    Read a test log written by other purposes. Set up a
#    fileevent reader to parse the log. Then wait for it
#    to finish.
#
#  Arguments:
#    testlog   - log of a test run
#  Side Effects:
#    defines fileevent to parse the output
#    and hangs until the parser notifies us.
#-----------------------------------------------------------
proc tclunit::read_testlog {testlog} {
    variable rt

    init_for_tests
    set rt(testdirectory) ""

    # FIXME: this does not make much sense in this context
    #  Set timers
    set rt(started_tests) [clock milliseconds]
    set rt(finished_tests) 0

    #  Exec a tcl shell to run the scripts
    set rt(pipe) [open $testlog r]
    fconfigure $rt(pipe) -blocking 0 -buffering line
    fileevent $rt(pipe) readable [namespace code [list capture_test_output $rt(pipe)]]

    set rt(phase) "start"

    #  Wait for the parser to finish
    vwait [namespace which -variable rt](finished_tests)

    #  check the time
    set rt(finished_tests) [clock milliseconds]
}

#-----------------------------------------------------------
#  tclunit::test_properties
#
#  Description:
#    Test suites started through runAllTests emit a couple of lines
#    describing the test environment, this is trying to catch them
#    and then raises a property event. It stops scanning for properties
#    with the first test case.
#
#  Arguments:
#    line   - a line from the log
#  Side Effects:
#    calls property event handler
#-----------------------------------------------------------
proc tclunit::test_properties {line} {
    variable rt
    variable cbs
    variable known_props

    if {[string match "---- *" $line] ||
	[string match "++++ *" $line] ||
	[string match "==== *" $line]} {
	set rt(phase) "tests"
	return 0
    }

    set found 0
    foreach property $known_props {
	if {[string match "${property}*" $line]} {
	    set found 1
	    set value [string range $line [string length $property] end]
	    if {$value eq ""} {
		set value true
	    }
	    break
	}
    }
    if {!$found} {
	return 0

    } elseif {[string index $property end] eq ":"} {
	{*}$cbs(property) [string range $property 0 end-1] [string trim $value]

    } else {
	{*}$cbs(property) $property [string trim $value]
    }
    return 1
}

#-----------------------------------------------------------
#  tclunit::convert_datetime
#
#  Description:
#    Return either the clock seconds value or the empty string.
#
#  Arguments:
#    datetimestring   - a standard Tcl timestamp
#  Side Effects:
#    none
#-----------------------------------------------------------
proc tclunit::convert_datetime {datetimestring} {
    set dt [string trim $datetimestring]

    if {![catch {clock scan $dt} timestamp]} {
	# Free form scan succeeded.
	return $timestamp

    } elseif {![catch {clock scan $dt -format "%a %b %d %H:%M:%S %Z %Y"} timestamp]} {
	# Standard Tcl format scan succeeded.
	return $timestamp
    }

    # Signal non-standard Tcl datetime.
    return ""
}

#-----------------------------------------------------------
#  tclunit::started_tests
#
#  Description:
#    Test suites started through runAllTests emit two time stamps in standard
#    Tcl datetime format, signaling start and end time of the tests.
#
#  Arguments:
#    line   - a line from the test log
#  Side Effects:
#    stores the start time in CTO
#-----------------------------------------------------------
proc tclunit::started_tests {line} {
    variable rt
    variable cto
    variable timeprefix

    if {![string match "${timeprefix(start)} *" $line]} {
	return 0
    }

    set rt(phase) "tests"

    set datetime [string range $line [string length $timeprefix(start)] end]
    set cto(tests_started) [convert_datetime $datetime]
    return 1
}

#-----------------------------------------------------------
#  tclunit::finished_tests
#
#  Description:
#    Test suites started through runAllTests emit two time stamps in standard
#    Tcl datetime format, signaling start and end time of the tests.
#
#  Arguments:
#    line   - a line from the test log
#  Side Effects:
#    stores the time when the tests finished in CTO
#-----------------------------------------------------------
proc tclunit::finished_tests {line} {
    variable rt
    variable cto
    variable timeprefix

    if {![string match "${timeprefix(end)} *" $line]} {
	return 0
    }

    set rt(phase) "end"

    set datetime [string range $line [string length $timeprefix(end)] end]
    set cto(tests_finished) [convert_datetime $datetime]
    return 1
}

package provide tclunit 1.1
