#!/usr/bin/tclsh

# Copyright (c) 2025, Blair Kitchen
# All rights resetved.
#
# See the file "license.terms" for informatio on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.

#
# This script is used to pretty-print an ADIF file into a more
# readable format, with one record per line
#

package require Tcl 8.5
package require cmdline 1.3

source adif.tcl
package require adif 0.1

proc main {argc argv} {
    set options {
        {output.arg "" "name of the output file. stdout if ommitted"}
    }
    set usage ": pp_adif.tcl \[options] file1 file2 ...\noptions:"
    if {[catch {array set params [::cmdline::getoptions argv $options $usage]} result]} {
        puts $result
        exit -1
    }

    set outChan stdout
    if {$params(output) != ""} {
        set outChan [open $params(output) "w"]
    }

    foreach inputFile [::cmdline::getfiles $argv false] {

        ::adif::foreachRecordInFile adifRecord $inputFile {
            ::adif::writeRecord $outChan $adifRecord
        }
    }

    close $outChan
}

main $argc $argv
