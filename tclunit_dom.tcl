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

proc tclunit_dom::suite_name {filename} {
    if {$filename eq ""} {
	return "unknown"
    } else {
	return [file rootname [file tail $filename]]
    }
}

# FIXME: create testsuite@name(String),hostname(String),package(String),timestamp(yyyy-MM-ddTHH:mm:ss),id(Int)
# FIXME: close  testsuite@tests(Int),errors(Int),failures(Int),skipped(Int),time(Float)
proc tclunit_dom::new_testsuite {filename} {
    variable generatedId
    variable testDocument
    variable currentNode

    close_tags

    incr generatedId 1

    $testDocument createElement testsuite testSuite
    $testSuite setAttribute name [suite_name $filename] \
	hostname [info hostname] id $generatedId
    $currentNode appendChild $testSuite
    set currentNode $testSuite
}

proc tclunit_dom::close_tags {} {
    variable testDocument
    variable currentNode

    $testDocument documentElement currentNode
}

# FIXME: testcase@name(String),classname(String),time(Float)
# testcase/failure@type,message/#text
# FIXME: testcase/skipped@type,message/#text
# TODO: testcase/error@message/#text
proc tclunit_dom::set_testcase {type filename testcase {reason ""} {time 0}} {
    variable testDocument
    variable currentNode

    $testDocument createElement testcase testCase
    $currentNode appendFromScript {
	testcase -name $testcase -classname [suite_name $filename] {
	    if {$type eq "failed"} {
		failure -type CASE_FAILED -message "$testcase FAILED" {
		    reason $reason
		}
	    } elseif {$type eq "skipped"} {
		skipped -type CASE_SKIPPED {
		    reason $reason
		}
	    }
	}
    }
}

# TODO: system-out/#text at testcase or testsuite level
# TODO: system-err/#text at testcase or testsuite level

# properties/property@name(String),value(String)
proc tclunit_dom::set_property {name value} {
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

    $Properties appendFromScript {
	property -name $name -value $value
    }
}

proc tclunit_dom::main {args} {
    variable testDocument
    variable currentNode

    tclunit::configure \
	event init [namespace code close_tags] \
	event suite [namespace code new_testsuite] \
	event skipped [namespace code {set_testcase skipped}] \
	event passed [namespace code {set_testcase passed}] \
	event failed [namespace code {set_testcase failed}] \
	event property [namespace code set_property]

    # /testsuites
    dom createDocument testsuites testDocument
    $testDocument documentElement currentNode

    dom createNodeCmd elementNode testcase
    dom createNodeCmd elementNode skipped
    dom createNodeCmd elementNode failure
    dom createNodeCmd textNode reason
    dom createNodeCmd elementNode property

    foreach path $args {
	tclunit::run_tests $path
    }
    puts "<?xml version=\"1.0\" encoding=\"UTF-8\" ?>"
    $testDocument asXML -indent 2 -channel stdout
}

if {[info exists argv]} {
    tclunit_dom::main {*}$argv
}
