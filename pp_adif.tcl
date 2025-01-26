#!/usr/bin/tclsh

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
        set inChan [open $inputFile "r"]

        set adifRecord [::adif::readNextRecord $inChan]
        while {[dict size $adifRecord] != 0} {
            ::adif::writeRecord $outChan $adifRecord
            set adifRecord [::adif::readNextRecord $inChan]
        }

        close $inChan
    }

    close $outChan
}

main $argc $argv
