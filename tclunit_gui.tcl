#!/usr/bin/env wish
#-----------------------------------------------------------
#
#  tclunit_gui
#
#  Tclunit is a simple GUI wrapper around the tcltest
#  unit test framework.  It will give you the "green bar"
#  that makes so many developers happy.
#
#  Synopsis:
#     tclunit_gui [testFile | testDirectory]
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
#
#  This is now splitted into the basic functionality and the
#  GUI code. The functionality can be found in the tclunit
#  package. This GUI code has been touched at various places
#  to better fit into the new architecture, but otherwise
#  left as initially written by Bob. Except ... everything
#  is now in its proper namespace.
#
#  Matthias Kraft
#  June 12, 2012
#
#-----------------------------------------------------------
# GUI components for tclunit

package require Tk 8.5
package require Ttk
package require tclunit

namespace eval tclunit_gui {
    variable widget		;# Array with GUI components
    variable testResults	;# Array with visible test results

    variable runAllTests 1
    variable testFile ""
    variable testDirectory [pwd]
}

#-----------------------------------------------------------
#  tclunit_gui::initgui_for_tests
#
#  Description:
#    Initializes GUI for running test suite. Serves as <init>
#    callback for tclunit.
#
#  Arguments
#    none
#
#  Side Effects
#    Cleans out GUI display
#
#-----------------------------------------------------------
proc tclunit_gui::initgui_for_tests {} {
    variable testResults
    variable widget

    #  Initialize results array
    array unset testResults

    #  Initialize GUI, basically by deleting contents
    $widget(txt) delete 1.0 end
    $widget(tv) delete [$widget(tv) children {}]
    $widget(ind) configure -background green -text "So Far So Good..."
    update idletasks
}

#-----------------------------------------------------------
#  tclunit_gui::show_test_skipped
#
#  Description:
#    Add the test to the GUI. Serves as <skipped> callback
#    for tclunit.
#
#  Arguments:
#    filename - the test suite currently running
#    testName - the name of the skipped test case
#    reason - the tcltest constraint name
#
#  Side Effects:
#    changes the GUI
#-----------------------------------------------------------
proc tclunit_gui::show_test_skipped {filename testName reason} {
    variable testResults
    variable widget

    # update the GUI
    set id [$widget(tv) insert $filename end \
	-text $testName -image tclunit_gui::skippedIcon]
    update idletasks

    #  Save a text string for display
    set testResults($id) "SKIPPED: $reason"
}

#-----------------------------------------------------------
#  tclunit_gui::show_test_passed
#
#  Description:
#    Add the test to the GUI. Serves as <passed> callback
#    for tclunit.
#
#  Arguments:
#    filename - the test suite currently running
#    testName - the name of the skipped test case
#
#  Side Effects:
#    changes the GUI
#-----------------------------------------------------------
proc tclunit_gui::show_test_passed {filename testName} {
    variable testResults
    variable widget

    #  update the GUI
    set id [$widget(tv) insert $filename end \
	-text $testName -image tclunit_gui::passedIcon]
    update idletasks

    #  Save a text string for display
    set testResults($id) PASSED
}

#-----------------------------------------------------------
#  tclunit_gui::show_test_failed
#
#  Description:
#    Add this test to the GUI. Serves as <failed> callback
#    for tclunit.
#
#  Arguments:
#    filename - the test suite currently running
#    testName - the name of the skipped test case
#    report - the usual tcltest failure report
#
#  Side Effects:
#    updates the GUI.
#-----------------------------------------------------------
proc tclunit_gui::show_test_failed {filename testName report} {
    variable testResults
    variable widget

    #  Add the test to the gui
    set id [$widget(tv) insert $filename end \
	-text $testName -image tclunit_gui::failedIcon]
    $widget(tv) item $filename -image tclunit_gui::failedIcon
    $widget(ind) configure -background red -text "TEST FAILURES"
    update idletasks

    #  Save a text string for display
    set testResults($id) $report
}

#-----------------------------------------------------------
#  tclunit_gui::show_test_file_start
#
#  Description:
#    Adds the file to the GUI. Serves as <suite> callback for
#    tclunit.
#
#  Arguments:
#    filename - name of test file (that is about to be run)
#
#  Side Effects:
#    changes the GUI
#-----------------------------------------------------------
proc tclunit_gui::show_test_file_start {filename} {
    variable testResults
    variable widget

    #  Add this filename to the GUI
    $widget(tv) insert {} end -id $filename \
	-text $filename -open false -image tclunit_gui::passedIcon
    update idletasks

    #  Initialize test results, so users see something when
    #  the filename is selected in the treeview
    set testResults($filename) ""
}

#-----------------------------------------------------------
#  tclunit_gui::update_test_status
#
#  Description:
#    Update the status report in the GUI. Serves as <status>
#    callback for tclunit.
#
#  Arguments:
#    filename - the test suite currently running
#    passed - number of passed tests of the suite
#    skipped - number of skipped tests of the suite
#    failed - number of failed tests of the suite
#
#  Side Effects:
#    changes the GUI
#-----------------------------------------------------------
proc tclunit_gui::update_test_status {filename passed skipped failed} {
    variable statusLine
    variable testResults

    set total [expr {$passed + $skipped + $failed}]
    set statusLine \
	[format "%-20s:  Total %-5d    Passed %-5d    Skipped %-5d    Failed %-5d" \
	$filename $total $passed $skipped $failed]

    #  Copy summary to this test file's results
    set testResults($filename) $statusLine
}

#-----------------------------------------------------------
#  tclunit_gui::finale_test_status
#
#  Description:
#    Show the final test status report in the GUI. Serves as
#    <total> callback for tclunit.
#
#  Arguments:
#    passed - number of all passed tests
#    skipped - number of all skipped tests
#    failed - number of all failed tests
#    time - time in ms for running all tests
#
#  Side Effects:
#    changes the GUI
#-----------------------------------------------------------
proc tclunit_gui::final_test_status {passed skipped failed time} {
    variable statusLine
    variable testResults

    #  look at final statistics
    set total [expr {$passed + $skipped + $failed}]

    # Computing timing statistic
    set velocity [expr {1000.0 * $total / $time}]

    # update GUI indicator
    set statusLine \
	[format "Total %-5d Passed %-5d Skipped %-5d Failed %-5d    (%.1f tests/second)" \
	$total $passed $skipped $failed $velocity]
}

#-----------------------------------------------------------
#  tclunit_gui::build_gui
#
#  Description:
#    Builds the GUI main window using tile widgets.
#    This was constructed and tested with tile 0.6.5,
#    but may work with other versions.
#
#    Note that the big green/red pass/fail indicator
#    is a regular Tk label, which allows background
#    color changes.
#
#  Arguments:
#    none
#  Side Effects:
#    creates a simple GUI and defines a namespace
#    variable, widget(), with a few names of
#    widgets that are used throughout the application.
#-----------------------------------------------------------

proc tclunit_gui::build_gui {} {
    variable widget
    variable statusLine
    variable runAllTests
    variable testFile
    variable testDirectory

    #  Select a test file or "run all tests"
    #  in a specific directory
    set ff [ttk::frame .fileframe]
    set frad [ttk::radiobutton $ff.filecheck -text "Test File" \
	-variable [namespace which -variable runAllTests] -value 0]
    set fent [ttk::entry $ff.filentry \
	-textvariable [namespace which -variable testFile]]
    set fbut [ttk::button $ff.filebtn -text "Browse..." \
	-command [namespace code browseFile]]

    set arad [ttk::radiobutton $ff.allcheck -text "Run All Tests" \
	-variable [namespace which -variable runAllTests] -value 1]
    set aent [ttk::entry $ff.allentry \
	-textvariable [namespace which -variable testDirectory]]
    set abut [ttk::button $ff.allbtn -text "Choose Dir..." \
	-command [namespace code browseDir]]

    grid $frad $fent $fbut -sticky ew -padx 4 -pady 4
    grid $arad $aent $abut -sticky ew -padx 4 -pady 4
    grid columnconfigure $ff 1 -weight 1

    # Paned window
    # FIXME: deprecated! use ::ttk::panedwindow instead
    set pw [ttk::paned .pw -orient horizontal]

    # tree view of tests run
    set tvf [ttk::frame $pw.tvf]
    set tv [ttk::treeview $tvf.tv -yscrollcommand [list $tvf.vsb set]]
    set sb [ttk::scrollbar $tvf.vsb -orient vertical \
	-command [list $tvf.tv yview]]

    grid $tv $sb -sticky news -padx 4 -pady 4
    grid columnconfigure $tvf 0 -weight 1
    grid    rowconfigure $tvf 0 -weight 1

    #  set treeview selection action
    bind $tv <<TreeviewSelect>> [namespace code gui_treeview_select]

    $pw add $tvf

    #  frame to hold "run" button and test results text
    set bf [ttk::frame $pw.bf]

    #  buttons to run/stop tests, color indicator, and text
    set run  [ttk::button $bf.run  -text "Run" \
	-command [namespace code gui_run_tests]]
    set stop [ttk::button $bf.stop -text "Stop" \
	-command [namespace code gui_stop_tests] -state disabled]
    # TODO: create styles and then use ttk::label
    set ind [label $bf.indicator -text "" -background green]
    set txt [text $bf.text]

    grid $run  $ind   -sticky news -padx 4 -pady 4
    grid $stop   ^    -sticky news -padx 4 -pady 4
    grid $txt    -    -sticky news -padx 4 -pady 4
    grid columnconfigure $bf 1 -weight 1
    grid    rowconfigure $bf 2 -weight 1

    $pw add $bf

    #  add a status line
    set statline [ttk::label .statusLine \
	-textvariable [namespace which -variable statusLine]]

    #  Assemble the main window parts
    grid $ff -sticky ew
    grid $pw -sticky news
    grid $statline -sticky w -padx 4 -pady 4

    grid columnconfigure . 0 -weight 1
    grid    rowconfigure . 1 -weight 1

    # save widget names
    set widget(run)  $run
    set widget(stop) $stop
    set widget(tv)   $tv
    set widget(txt)  $txt
    set widget(ind)  $ind

    #  Define icons for the tree view

    #  actcheck16 from crystal icons
    image create photo tclunit_gui::passedIcon -data {
       R0lGODlhEAAQAIIAAPwCBMT+xATCBASCBARCBAQCBEQCBAAAACH5BAEAAAAA
       LAAAAAAQABAAAAM2CLrc/itAF8RkdVyVye4FpzUgJwijORCGUhDDOZbLG6Nd
      2xjwibIQ2y80sRGIl4IBuWk6Af4EACH+aENyZWF0ZWQgYnkgQk1QVG9HSUYg
       UHJvIHZlcnNpb24gMi41DQqpIERldmVsQ29yIDE5OTcsMTk5OC4gQWxsIHJp
       Z2h0cyByZXNlcnZlZC4NCmh0dHA6Ly93d3cuZGV2ZWxjb3IuY29tADs=
    }

    #  actcross16 from crystal icons
    image create photo tclunit_gui::failedIcon -data {
       R0lGODlhEAAQAIIAAASC/PwCBMQCBEQCBIQCBAAAAAAAAAAAACH5BAEAAAAA
       LAAAAAAQABAAAAMuCLrc/hCGFyYLQjQsquLDQ2ScEEJjZkYfyQKlJa2j7AQn
       MM7NfucLze1FLD78CQAh/mhDcmVhdGVkIGJ5IEJNUFRvR0lGIFBybyB2ZXJz
       aW9uIDIuNQ0KqSBEZXZlbENvciAxOTk3LDE5OTguIEFsbCByaWdodHMgcmVz
       ZXJ2ZWQuDQpodHRwOi8vd3d3LmRldmVsY29yLmNvbQA7
    }

    #  services-16 from crystal icons
    image create photo tclunit_gui::skippedIcon -data {
       R0lGODlhEAAQAIUAAPwCBPy2BPSqBPSeBPS6HPSyDPSmBPzSXPzGNOyOBPSy
       FPzujPzaPOyWBPy+DPyyDPy+LPzKTPzmZPzeTPSaFOSGBNxuBNxmBPzWVPzq
       dPzmXPzePPzaRPzeRPS2FNxqBPzWNOyeBPTCLPzOJNxyBPzGHNReBOR6BOR2
       BNRmBMxOBMxWBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
       AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACH5BAEAAAAALAAAAAAQABAAAAZz
       QIBwSCwahYHA8SgYLIuEguFJFBwQCSpAMVgwEo2iI/mAECKSCYFCqVguF0BA
       gFlkNBsGZ9PxXD5EAwQTEwwMICAhcUYJInkgIyEWSwMRh5ACJEsVE5EhJQQm
       S40nKCQWAilHCSelQhcqsUatRisqWkt+QQAh/mhDcmVhdGVkIGJ5IEJNUFRv
       R0lGIFBybyB2ZXJzaW9uIDIuNQ0KqSBEZXZlbENvciAxOTk3LDE5OTguIEFs
       bCByaWdodHMgcmVzZXJ2ZWQuDQpodHRwOi8vd3d3LmRldmVsY29yLmNvbQA7
    }
}

#-----------------------------------------------------------
#  tclunit_gui::gui_run_tests
#
#  Description:
#    Called by the "Run" button, this proc calls
#    tclunit::run_tests, then shows a nice summary of the
#    tests and updates the GUI.
#
#  Arguments:
#    none
#  Side Effects
#    Pretty much everything happens.
#-----------------------------------------------------------
proc tclunit_gui::gui_run_tests {} {
    variable widget
    variable statusLine
    variable runAllTests
    variable testFile
    variable testDirectory

    #  enable/disable the buttons
    $widget(run)  configure -state disabled
    $widget(stop) configure -state normal

    #  run the tests
    if {$runAllTests} {
	tclunit::run_tests $testDirectory
    } else {
	tclunit::run_tests $testFile
    }

    # update GUI indicator
    $widget(ind) configure -text $statusLine

    #  enable/disable the buttons
    $widget(run)  configure -state normal
    $widget(stop) configure -state disabled
}

#-----------------------------------------------------------
#  tclunit_gui::gui_stop_tests
#
#  Description:
#    Called by the "Stop" button, this proc just calls
#    tclunit::stop_tests. Implicitely also changes the
#    enabled states of the buttons.
#
#  Arguments:
#    none
#  Side Effects
#    Pretty much everything stops.
#-----------------------------------------------------------
proc tclunit_gui::gui_stop_tests {} {
    tclunit::stop_tests
}

#-----------------------------------------------------------
#  tclunit_gui::gui_treeview_select
#
#  Description:
#    Called by the <<TreeviewSelect>> event binding,
#    this procedure figures out the $id of the
#    selected entry and copies the proper text results
#    into the text widget.
#
#  Arguments:
#    none
#  Side Effects:
#    Changes text widget contents
#-----------------------------------------------------------
proc tclunit_gui::gui_treeview_select {} {
    variable widget
    variable testResults

    # get selection from treeview
    set id [$widget(tv) selection]

    # display text
    set txt $widget(txt)
    $txt delete 1.0 end
    $txt insert end $testResults($id)
}

#-----------------------------------------------------------
#  tclunit_gui::browseFile
#
#  Description:
#    Called by the file "Browse..." button, this procedure
#    opens tk_getOpenFile and save the selected test file
#    name to a variable.
#
#  Arguments:
#    none
#  Side Effects
#    Sets testFile and runAllTests variables
#-----------------------------------------------------------
proc tclunit_gui::browseFile {} {
    variable testFile
    variable runAllTests

    set dirname [file dirname $testFile]
    if { $dirname eq "" } {
	set dirname [pwd]
    }
    set filetypes {
        {{Test Files} {.test .tcl}}
        {{All Files}   *          }
    }

    set filename [tk_getOpenFile -initialdir $dirname -filetypes $filetypes]
    if { $filename ne "" } {
	cd [file dirname $filename]
	set testFile [file tail $filename]
	set runAllTests 0
    }
}

#-----------------------------------------------------------
#  tclunit_gui::browseDir
#
#  Description:
#    Called by the directory "Select Dir..." button,
#    this procedure opens tk_chooseDirectory to
#    select a new directory for running all tests.
#
#  Arguments:
#    none
#  Side Effects:
#    Sets the variables testDirectory and runAllTests
#-----------------------------------------------------------
proc tclunit_gui::browseDir {} {
    variable testDirectory
    variable runAllTests

    set dirname [tk_chooseDirectory -initialdir $testDirectory]

    if { $dirname ne "" } {
	set testDirectory $dirname
	set runAllTests 1
    }
}

#-----------------------------------------------------------
#  tclunit_gui::main
#
#  Description:
#    Main program, parses command line arguments to
#    figure out if the user specified either a directory
#    or a test file.  It then loads the gui script and builds
#    the GUI.
#
#  Arguments:
#    args - command line arguments (argv) the first of
#           which might be a file name
#  Side Effects:
#    configures tclunit package and runs the program
#-----------------------------------------------------------
proc tclunit_gui::main {args} {
    variable runAllTests
    variable testFile
    variable testDirectory

    if { [llength $args] > 0 } {
	if { [file exists [lindex $args 0]] } {
	    set filename [lindex $args 0]

	    if { ! [file isdirectory $filename] } {
		set runAllTests 0
		set testFile $filename
	    } else {
		set testDirectory $filename
	    }
	}
    }

    tclunit::configure \
	event init [namespace code initgui_for_tests] \
	event skipped [namespace code show_test_skipped] \
	event passed [namespace code show_test_passed] \
	event failed [namespace code show_test_failed] \
	event suite [namespace code show_test_file_start] \
	event status [namespace code update_test_status] \
	event total [namespace code final_test_status]

    build_gui
}

if {[info exists argv]} {
    tclunit_gui::main $argv
}
