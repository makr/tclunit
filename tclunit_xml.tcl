#!/usr/bin/env tclsh8.5
#-----------------------------------------------------------
#
#  tclunit_xml
#
# Tclunit_XML is using the refactored and extend tclunit package
# to run testsuites or parse test logs and create jUnit compatible
# XML reports from it.
#
#  Matthias Kraft
#  June 19, 2012
#
#-----------------------------------------------------------
# XML converter for tclunit

package require tclunit 1.1

namespace eval tclunit_xml {
    variable openedTags {} ;# list of tags to close
}

proc tclunit_xml::new_testsuite {filename} {
    variable openedTags

    close_tags

    puts [format {<testsuite name="%s">} [file rootname [file tail $filename]]]
    lappend openedTags testsuite
}

proc tclunit_xml::close_tags {} {
    variable openedTags

    foreach tag [lreverse $openedTags] {
	puts [format {</%s>} $tag]
    }

    set openedTags {}
}

proc tclunit_xml::testcase_skipped {filename testcase reason} {
    puts [format {<testcase name="%s" classname="%s">} \
	$testcase [file rootname [file tail $filename]]]
    puts [format {<skipped type="CASE_SKIPPED">%s</skipped>} $reason]
    puts "</testcase>"
}

proc tclunit_xml::testcase_passed {filename testcase {time 0}} {
    puts [format {<testcase name="%s" classname="%s"/>} \
	$testcase [file rootname [file tail $filename]]]
}

proc tclunit_xml::testcase_failed {filename testcase report {time 0}} {
    puts [format {<testcase name="%s" classname="%s">} \
	$testcase [file rootname [file tail $filename]]]
    puts [format {<failure type="CASE_FAILED" message="%s FAILED">%s</failure>} \
	$testcase $report]
    puts "</testcase>"
}

proc tclunit_xml::property {name value} {
    variable openedTags

    if {[lindex $openedTags end] ne "properties"} {
	puts "<properties>"
	lappend openedTags properties
    }
    puts [format {<property name="%s" value="%s"/>} $name $value]
}

proc tclunit_xml::main {args} {
    tclunit::configure \
	event init [namespace code close_tags] \
	event suite [namespace code new_testsuite] \
	event skipped [namespace code testcase_skipped] \
	event passed [namespace code testcase_passed] \
	event failed [namespace code testcase_failed] \
	event property [namespace code property]

    puts "<?xml version=\"1.0\" encoding=\"UTF-8\" ?>"
    puts "<testsuites>"
    foreach path $args {
	tclunit::run_tests $path
    }
    close_tags
    puts "</testsuites>"
}

if {[info exists argv]} {
    tclunit_xml::main {*}$argv
}
