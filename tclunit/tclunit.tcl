#-----------------------------------------------------------
#
#  tclunit
#
#  Tclunit is a simple GUI wrapper around the tcltest
#  unit test framework.  It will give you the "green bar"
#  that makes so many developers happy.
#
#  Synopsis:
#     tclunit [testFile | testDirectory]
#
#  Tclunit will execute a single test file, or run
#  all tests in a directory using tcltest's runAllTests
#  procedure.  Test output is captured, parsed, and
#  presented in the GUI.
#
#  Each file is listed in a tree view, with a green
#  check if all tests passed, or a red "x" if any
#  test failed.  Opening the file in the tree view
#  lists all tests individually.  Selecting any test
#  shows its output in the text view.
#
#  This program was developed with an early release
#  of the "tile" themable widget package.  It may
#  work with pre-0.6.5 releases, but it hasn't been
#  tested.  The latest ActiveTcl releases should
#  work just fine.
#
#  This program was created en-route to the Tcl/Tk 2005
#  conference, as a quick demo to share with the
#  attendees.  It isn't exactly robust.  It was not
#  employed with any particulary saavy development
#  strategies, like Model-View-Controller.  There are
#  a bunch of marginally documented global variables.
#  But worst of all, there isn't a test suite.
#
#  But with those apologies, please enjoy.
#
#
#  Bob Techentin
#  October 24, 2005
#
#-----------------------------------------------------------

package require Tcl 8.5

namespace eval tclunit {
    variable cto	 ;# Capturing Test Output array

    variable rt		 ;# Array with runtime configuration
    set rt(testFile)	  ""
    set rt(testDirectory) ""
    set rt(runAllTests)	  1
    set rt(interp)	  [info nameofexecutable]

    set rt(withGUI) 0 ;# FIXME: wrong turn!!!

    variable cbs	 ;# Array with callbacks for events
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
#    Configuration of the tclunit module.
#
#  Arguments:
#    event <tag> <script> - register <script> for event <tag>
#    interp <path to interpreter> - interpreter to use for testing
#
#  Side Effects:
#    Configuration changes.
#-----------------------------------------------------------
proc tclunit::configure {args} {
    variable cbs
    variable rt

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
	    default {
		return -code error "unknown command $cmd, must be event or interp"
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

    # Run tests with verbose options
    #   so we can parse the output
    # TODO; move setup of TCLTEST_OPTIONS into testScript
    # TODO: filter existing options, provide possibility to add further options
    set ::env(TCLTEST_OPTIONS) "-verbose {body pass skip start error}"

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
#    Creates a test script for running
#    all tests in the current working
#    directory.  Then runs the tests.
#
#  Arguments:
#    none
#  Side Effects:
#    runs all the tests in the directory
#-----------------------------------------------------------
proc tclunit::run_all_tests {} {
    init_for_tests
    set testScript {
	package require tcltest
	tcltest::runAllTests
	exit
    }
    do_run_tests $testScript
}

#-----------------------------------------------------------
#  tclunit::run_test_file
#
#  Description:
#    Creates a test script for running
#    a single test file, then runs the tests.
#
#  Arguments:
#    testfile  - file to be tested
#  Side effects:
#    runs the test file
#-----------------------------------------------------------
proc tclunit::run_test_file {testfile} {
    init_for_tests
    set testScript {
	source $testfile
	exit
    }
    set testScript [subst $testScript]
    test_file_start $testfile
    do_run_tests $testScript
}

#-----------------------------------------------------------
#  tclunit::do_run_tests
#
#  Description:
#    Run tclsh and feed it the test script written by
#    run_all_tests or run_test_file.  Set up a fileevent
#    reader to parse the output.  Then wait for it
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

    if {[eof $chan]} {
	# notify [do_run_tests] that we've completed
	set rt(finished_tests) 1
	close $chan
	return
    }

    # Read the line
    gets $chan line

    #  If we're saving up test results...
    if { $cto(capturing) } {
	test_failed_continue $line
	return
    }

    # TODO: also capture test properties, e.g. interpreter, test directory, etc.

    #  Check for start, pass and fail lines
    switch -glob -- $line {
	"++++ * PASSED"     {test_passed $line}
	"==== * FAILED"     {test_failed $line}
	"---- * start"      {test_started $line}
	"++++ * SKIPPED: *" {test_skipped $line}
    }

    #  If the line is a file name
    #   then save it
    if { [file exists $line] } {
	test_file_start $line
    }
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
    scan $line "++++ %s SKIPPED: %s" testName reason
    {*}$cbs(skipped) $cto(filename) $testName $reason
}

#-----------------------------------------------------------
#  tclunit::test_started
#
#  Description:
#    Parse the test name from the line, and
#    reset the capture test ouput (cto) variables.
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
    {*}$cbs(start) $testName
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
    variable rt
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
#    the "FAILED" line.
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
#    Note that the "Result should have been..." line
#    seems to come with an attached newline, while every
#    other line requires a newline.  Not sure why this
#    special case is required to get test results that
#    look just like regular tcltest output on a console.
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

    append cto(result) "$line"
    if { ! [string match "*Result should have been*" $line] } {
	append cto(result) "\n"
    }

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
#    This proc decides
#    whether to call run_all_tests or run_test_file,
#    then makes a nice summary of the tests.
#
#  Arguments:
#    none
#
#  Side Effects
#    Pretty much everything happens.
#-----------------------------------------------------------
proc tclunit::run_tests {path} {
    variable cto
    variable rt
    variable cbs

    #  run the tests
    if {($path eq "") || ![file exists $path]} {
	return -code error "no test suite at '$path'"
    } elseif {[file isdirectory $path]} {
	set rt(runAllTests) 1 ;# FIXME: necessary?
	cd $path ;# TODO: move into testScript
	run_all_tests
    } else {
	set rt(runAllTests) 0 ;# FIXME: necessary?
	cd [file dirname $path] ;# TODO: move into testScript
	run_test_file $path
    }

    # Computing timing statistic
    set time_in_ms [expr {$rt(finished_tests) - $rt(started_tests)}]

    # send final statistics
    {*}$cbs(total) $cto(totalpassed) $cto(totalskipped) $cto(totalfailed) $time_in_ms
}

#-----------------------------------------------------------
#  tclunit::stop_tests
#
#  Description:
#    This procedure terminates
#    the running test process by closing the pipe and
#    setting the global flag.
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

package provide tclunit 1.1
