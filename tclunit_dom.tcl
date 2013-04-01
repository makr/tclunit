#!/usr/bin/env tclsh8.5
#-----------------------------------------------------------
#
#  tclunit_dom
#
# Tclunit_DOM is using the refactored and extend tclunit package
# to run testsuites or parse test logs and create jUnit compatible
# XML reports from it. It is creating a DOM tree in memory before
# dumping it as XML.
#
#  Matthias Kraft
#  April 1, 2013
#
#-----------------------------------------------------------
# XML converter for tclunit

package require tdom 0.8.3
package require tclunit 1.1

namespace eval tclunit_dom {
    variable testDocument
}

proc tclunit_dom::new_testsuite {filename} {
    variable testDocument
    variable currentNode

    close_tags

    $testDocument createElement testsuite testSuite
    $testSuite setAttribute name [file rootname [file tail $filename]]
    $currentNode appendChild $testSuite
    set currentNode $testSuite
}

proc tclunit_dom::close_tags {} {
    variable testDocument
    variable currentNode

    $testDocument documentElement currentNode
}

proc tclunit_dom::testcase_skipped {filename testcase reason} {
    variable testDocument
    variable currentNode

    $testDocument createElement testcase testCase
    $currentNode appendChild $testCase
    $testCase setAttribute name $testcase \
	classname [file rootname [file tail $filename]]

    $testDocument createElement skipped Skipped
    $testCase appendChild $Skipped
    $Skipped setAttribute type CASE_SKIPPED

    $testDocument createTextNode $reason Reason
    $Skipped appendChild $Reason
}

proc tclunit_dom::testcase_passed {filename testcase {time 0}} {
    variable testDocument
    variable currentNode

    $testDocument createElement testcase testCase
    $currentNode appendChild $testCase
    $testCase setAttribute name $testcase \
	classname [file rootname [file tail $filename]]
}

proc tclunit_dom::testcase_failed {filename testcase report {time 0}} {
    variable testDocument
    variable currentNode

    $testDocument createElement testcase testCase
    $currentNode appendChild $testCase
    $testCase setAttribute name $testcase \
	classname [file rootname [file tail $filename]]

    $testDocument createElement failure Failure
    $testCase appendChild $Failure
    $Failure setAttribute type CASE_FAILED message "$testcase FAILED"

    $testDocument createTextNode $report Report
    $Failure appendChild $Report
}

proc tclunit_dom::property {name value} {
    variable testDocument

    $testDocument documentElement Root
    $Root firstChild Properties

    if {$Properties eq ""} {
	$testDocument createElement properties Properties
	$Root appendChild $Properties

    } elseif {[$Properties nodeName] ne "properties"} {
	set Old1st $Properties
	$testDocument createElement properties Properties
	$Root insertBefore $Properties $Old1st
    }

    $testDocument createElement property Property
    $Property setAttribute name $name value $value
    $Properties appendChild $Property
}

proc tclunit_dom::main {args} {
    variable testDocument
    variable currentNode

    tclunit::configure \
	event init [namespace code close_tags] \
	event suite [namespace code new_testsuite] \
	event skipped [namespace code testcase_skipped] \
	event passed [namespace code testcase_passed] \
	event failed [namespace code testcase_failed] \
	event property [namespace code property]

    dom createDocument testsuites testDocument
    $testDocument documentElement currentNode

    foreach path $args {
	tclunit::run_tests $path
    }
    puts "<?xml version=\"1.0\" encoding=\"UTF-8\" ?>"
    $testDocument asXML -indent 2 -channel stdout
}

if {[info exists argv]} {
    tclunit_dom::main {*}$argv
}
