#!/usr/bin/env wish
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
    variable testResults ;# results array
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
#
#-----------------------------------------------------------
proc tclunit::init_for_tests {} {
    variable cto
    variable testResults

    # Run tests with verbose options
    #   so we can parse the output
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
      statusLine ""
    }

    #  Initialize results array
    array unset testResults

    # Initialize GUI if available
    if {$::GUI} {
	initgui_for_tests
    }
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

    #  Set timers
    set ::started_tests [clock clicks -milliseconds]
    set ::finished_tests 0

    #  Exec a tcl shell to run the scripts
    set ::pipe [open "|tclsh" w+]
    fconfigure $::pipe -blocking 0 -buffering line
    fileevent $::pipe readable [namespace code [list capture_test_output $::pipe]]

    #  Tell the shell what to do
    puts $::pipe $testScript

    #  And wait for it to finish
    vwait ::finished_tests

    #  check the time
    set ::finished_tests [clock clicks -milliseconds]

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

    if {[eof $chan]} {
	# notify [do_run_tests] that we've completed
	set ::finished_tests 1
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
    variable testResults

    incr_test_counter "skipped"

    if {$::GUI} {
	# update the GUI
	scan $line "%s %s" junk testName
	set id [show_test_skipped $cto(filename) $testName]
	#  Save a text string for display
	set testResults($id) $line
    }
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

    scan $line "---- %s start" testName
    set cto(testName) $testName
    set cto(result) ""
    set cto(capturing) 0
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
    variable testResults

    incr_test_counter "passed"

    if {$::GUI} {
	#  update the GUI
	set id [show_test_passed $cto(filename) $cto(testName)]
	#  Save a text string for display
	set testResults($id) PASSED
    }
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
    variable cto
    variable testResults

    append cto(result) "$line"
    if { ! [string match "*Result should have been*" $line] } {
	append cto(result) "\n"
    }

    #  Is this the last line in the failure log?
    if { $line eq "==== $cto(testName) FAILED" } {
	set cto(capturing) 0

	if {$::GUI} {
	    #  Add the test to the gui
	    set id [show_test_failed $cto(filename) $cto(testName)]
	    #  Save a text string for display
	    set testResults($id) $cto(result)
	}
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
    variable cto
    variable testResults

    #  Save the filename (which is the only thing on the line)
    lappend cto(filenames) $filename
    set cto(filename) $filename

    #  Initialize the counters
    set cto(passed) 0
    set cto(skipped) 0
    set cto(failed) 0

    #  Initialize test results, so users see something when
    #  the filename is selected in the treeview
    set testResults($filename) ""

    #  Add this filename to the GUI
    if {$::GUI} {
	show_test_file_start $filename
    }
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
    variable testResults

    incr cto($resultType)
    incr cto(total$resultType)

    #  Update the summary line
    set total [expr {$cto(passed) + $cto(skipped) + $cto(failed)}]
    set cto(statusLine) \
            [format "%-20s:  Total %-5d    Passed %-5d    Skipped %-5d    Failed %d-5" \
              $cto(filename) $total $cto(passed) $cto(skipped) $cto(failed)]

    #  Copy summary to this test file's results
    set testResults($cto(filename)) $cto(statusLine)
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
proc tclunit::run_tests {} {
    variable cto

    #  run the tests
    if { $::runAllTests } {
      cd $::testDirectory
	run_all_tests
    } else {
      if { ! [file exists $::testFile] } {
          browseFile ;# FIXME GUI code
      }
      cd [file dirname $::testFile]
	run_test_file $::testFile
    }

    #  look at final statistics
    set passed $cto(totalpassed)
    set skipped $cto(totalskipped)
    set failed $cto(totalfailed)
    set total [expr {$passed + $skipped + $failed}]


    # Computing timing statistic
    set time_in_ms [expr {$::finished_tests - $::started_tests}]
    set velocity [expr {1000.0 * $total / $time_in_ms}]

    # update GUI indicator
    set cto(statusLine) \
        [format "Total %-5d Passed %-5d Skipped %-5d Failed %-5d    (%.1f tests/second)" \
                        $total $passed $skipped $failed $velocity]
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
    close $::pipe
    set ::finished_tests 1
}

#-----------------------------------------------------------
#  tclunit::main
#
#  Description:
#    Main program, parses command line arguments to
#    figure out if the user specified either a directory
#    or a test file.  It then builds the gui.
#
#  Arguments:
#    args - command line arguments (argv) the first of
#           which might be a file name
#  Side Effects:
#    runs the program
#-----------------------------------------------------------
# FIXME inits GUI vars and the GUI itself
proc tclunit::main {args} {

    #  process command line arguments
    set ::testFile ""
    set ::testDirectory [pwd]
    set ::runAllTests 1
    if { [llength $args] > 0 } {
	if { [file exists [lindex $args 0]] } {
	    set filename [lindex $args 0]

          if { ! [file isdirectory $filename] } {
              set ::runAllTests 0
              set ::testFile $filename
          } else {
              set ::testDirectory $filename
          }
	}
    }

    set ::GUI 1
    build_gui

}

tclunit::main $argv

