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
# GUI components for tclunit

package require Tk 8.5
package require Ttk
package require tclunit

namespace eval tclunit_gui {
    namespace path [list [namespace current] ::tclunit ::]
    variable widget	;# Array with GUI components
}

#-----------------------------------------------------------
#  tclunit_gui::initgui_for_tests
#
#  Description:
#    Initializes GUI for running test suite.
#
#  Arguments
#    none
#
#  Side Effects
#    Cleans out GUI display
#
#-----------------------------------------------------------
proc tclunit_gui::initgui_for_tests {} {
    variable widget

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
#    Add the test to the GUI.
#
#  Arguments:
#    filename - the test suite currently running
#    testName - the name of the skipped test case
#
#  Side Effects:
#    changes the GUI
#-----------------------------------------------------------
proc tclunit_gui::show_test_skipped {filename testName} {
    variable widget

    # update the GUI
    set id [$widget(tv) insert $filename end \
	-text $testName -image tclunit_gui::skippedIcon]
    update idletasks
    return $id
}

#-----------------------------------------------------------
#  tclunit_gui::show_test_passed
#
#  Description:
#    Add the test to the GUI.
#
#  Arguments:
#    filename - the test suite currently running
#    testName - the name of the skipped test case
#
#  Side Effects:
#    changes the GUI
#-----------------------------------------------------------
proc tclunit_gui::show_test_passed {filename testName} {
    variable widget

    #  update the GUI
    set id [$widget(tv) insert $filename end \
	-text $testName -image tclunit_gui::passedIcon]
    update idletasks
    return $id
}

#-----------------------------------------------------------
#  tclunit_gui::show_test_failed
#
#  Description:
#    Add this test to the GUI.
#
#  Arguments:
#    filename - the test suite currently running
#    testName - the name of the skipped test case
#
#  Side Effects:
#    updates the GUI.
#-----------------------------------------------------------
proc tclunit_gui::show_test_failed {filename testName} {
    variable widget

    #  Add the test to the gui
    set id [$widget(tv) insert $filename end \
	-text $testName -image tclunit_gui::failedIcon]
    $widget(tv) item $filename -image tclunit_gui::failedIcon
    $widget(ind) configure -background red -text "TEST FAILURES"
    update idletasks
    return $id
}

#-----------------------------------------------------------
#  tclunit_gui::show_test_file_start
#
#  Description:
#    Adds the file to the GUI.
#
#  Arguments:
#    filename - name of test file (that is about to be run)
#
#  Side Effects:
#    changes the GUI
#-----------------------------------------------------------
proc tclunit_gui::show_test_file_start {filename} {
    variable widget

    #  Add this filename to the GUI
    $widget(tv) insert {} end -id $filename \
	-text $filename -open false -image tclunit_gui::passedIcon
    update idletasks
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

proc tclunit_gui::build_gui {rtArray statusVariable} {
    variable widget

    #  Select a test file or "run all tests"
    #  in a specific directory
    set ff [ttk::frame .fileframe]
    set frad [ttk::radiobutton $ff.filecheck -text "Test File" \
	-variable ${rtArray}(runAllTests) -value 0]
    set fent [ttk::entry $ff.filentry -textvariable ${rtArray}(testFile)]
    set fbut [ttk::button $ff.filebtn -text "Browse..." \
	-command [namespace code browseFile]]

    set arad [ttk::radiobutton $ff.allcheck -text "Run All Tests" \
	-variable ${rtArray}(runAllTests) -value 1]
    set aent [ttk::entry $ff.allentry -textvariable ${rtArray}(testDirectory)]
    set abut [ttk::button $ff.allbtn -text "Choose Dir..." \
	-command [namespace code browseDir]]

    grid $frad $fent $fbut -sticky ew -padx 4 -pady 4
    grid $arad $aent $abut -sticky ew -padx 4 -pady 4
    grid columnconfigure $ff 1 -weight 1

    # Paned window
    set pw [ttk::paned .pw -orient horizontal] ;# FIXME deprecated! use ::ttk::panedwindow instead

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
    set ind [label $bf.indicator -text "" -background green] ;# TODO create styles instead
    set txt [text $bf.text]

    grid $run  $ind   -sticky news -padx 4 -pady 4
    grid $stop   ^    -sticky news -padx 4 -pady 4
    grid $txt    -    -sticky news -padx 4 -pady 4
    grid columnconfigure $bf 1 -weight 1
    grid    rowconfigure $bf 2 -weight 1

    $pw add $bf

    #  add a status line
    set statline [ttk::label .statusLine -textvariable $statusVariable]

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
#    Called by the "Run" button, this proc decides
#    whether to call run_all_tests or run_test_file,
#    then makes a nice summary of the tests and updates
#    the GUI.
#
#  Arguments:
#    none
#  Side Effects
#    Pretty much everything happens.
#-----------------------------------------------------------
proc tclunit_gui::gui_run_tests {} {
    variable widget
    variable cto

    #  enable/disable the buttons
    $widget(run)  configure -state disabled
    $widget(stop) configure -state normal

    #  run the tests
    run_tests ;# FIXME backref into main module

    # update GUI indicator
    $widget(ind) configure -text $cto(statusLine) ;# FIXME cto ref!

    #  enable/disable the buttons
    $widget(run)  configure -state normal
    $widget(stop) configure -state disabled
}

#-----------------------------------------------------------
#  tclunit_gui::gui_stop_tests
#
#  Description:
#    Called by the "Stop" button.  It also changes the enabled
#    states of the buttons.
#
#  Arguments:
#    none
#  Side Effects
#    Pretty much everything stops.
#-----------------------------------------------------------
# FIXME backref into main module
proc tclunit_gui::gui_stop_tests {} {
    stop_tests
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
#    Called by the file "Browse..." button,
#    this procedure opens tk_getOpenFile
#    and save the selected test file name to
#    a global variable.
#
#  Arguments:
#    none
#  Side Effects
#    Sets testFile and runAllTests global variables
#-----------------------------------------------------------
# FIXME $::testFile and $::runAllTests ref
proc tclunit_gui::browseFile {} {
    set dirname [file dirname $::testFile]
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
	set ::testFile [file tail $filename]
	set ::runAllTests 0
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
#    Sets the global variables testDirectory and runAllTests
#-----------------------------------------------------------
# FIXME $::testDirectory and $::runAllTests ref
proc tclunit_gui::browseDir {} {
    set dirname [tk_chooseDirectory -initialdir $::testDirectory]

    if { $dirname ne "" } {
	set ::testDirectory $dirname
	set ::runAllTests 1
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
#    runs the program
#-----------------------------------------------------------
proc tclunit_gui::main {args} {

    #  process command line arguments
    set rt(testDirectory) [pwd]
    set rt(withGUI) 1

    if { [llength $args] > 0 } {
	if { [file exists [lindex $args 0]] } {
	    set filename [lindex $args 0]

	    if { ! [file isdirectory $filename] } {
		set rt(runAllTests) 0
		set rt(testFile) $filename
	    } else {
		set rt(testDirectory) $filename
	    }
	}
    }

    build_gui [namespace which -variable rt] [namespace which -variable cto](statusLine)
}

if {[info exists argv]} {
    tclunit_gui::main $argv
}
