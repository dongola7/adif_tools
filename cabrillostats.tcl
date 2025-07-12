#!/bin/sh
# the next line restarts using tclsh \
exec tclsh "$0" "$@"

# Copyright (c) 2025, Blair Kitchen
# All rights reserved.
#
# See the file "license.terms" for informatio on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.

#
# Script to ingest a Cabrillo formatted file and output stats on QSOs by band and mode.
# Written to help with club log submission for 2025 ARRL Field Day.
#
package require Tcl 9.0
package require cmdline 1.3
package require fileutil 1.14

proc main {argc argv} {
    set options {
        {output.arg "" "name of the output file. stdout if ammitted"}
        {verbosity.arg "0" "logging verbosity (0, 1, 2)"}
    }
    set usage ": cabrillostats.tcl \[options] file1 file2 ... \noptions:"
    if {[catch {array set params [::cmdline::getoptions argv $options $usage]} result]} {
        puts $result
        exit -1
    }

    log::setVerbosity $params(verbosity)

    set outChan stdout
    if {$params(output) != ""} {
        set outChan [open $params(output) "w"]
    }

    # Initialize storage dict. Keys are bands. Values are
    # a nested dict with keys being the mode and values being
    # the number of QSOs.
    set stats [dict create]

    set malformedCount 0
    set matchedCount 0
    set nonQsoCount 0
    set totalRecordCount 0
    foreach inputFile [::cmdline::getfiles $argv false] {
        log::info "processing $inputFile"
        fileutil::foreachLine record $inputFile {
            set record [string trim $record]

            if {$record == ""} {
                # Skip empty records
                continue
            }

            incr totalRecordCount

            if {[string first "QSO:" $record] != 0} {
                incr nonQsoCount
                log::debug "skipping $record"
            } elseif {[regexp -- {QSO:[[:space:]]+([0-9]+)[[:space:]]+([A-Z]+)} $record -> freq mode]} {
                # Frequency is in Hz, convert to MHz
                set freq [expr {$freq/1000.0}]
                set band [freqToBand $freq]
                set mode [codeToMode $mode]

                if {![dict exists $stats $band $mode]} {
                    dict set stats $band $mode 0
                }
                set counter [dict get $stats $band $mode]
                dict set stats $band $mode [incr counter]

                incr matchedCount
                log::debug "matched $record freq=$freq band=$band mode=$mode"
            } else {
                incr malformedCount
                log::error "malformed $record"
            }
        }
    }

    log::debug "stats=$stats"

    set totalQsos 0
    foreach band [lsort [dict keys $stats]] {
        puts -nonewline $outChan "$band: "
        foreach mode [lsort [dict keys [dict get $stats $band]]] {
            incr totalQsos [dict get $stats $band $mode]
            puts -nonewline $outChan "$mode = [dict get $stats $band $mode] "
        }
        puts $outChan ""
    }

    puts $outChan "Processed $totalRecordCount Records, Non-QSO = $nonQsoCount, Good QSOs = $matchedCount, Malformed QSOs = $malformedCount"
}

#
# Given a Cabrillo encoded mode field, returns the human readable name. Returns
# UNKNOWN if the code is unknown.
#
proc codeToMode {code} {
    set code [string toupper $code]
    if {$code == "PH"} {
        return "Phone"
    } elseif {$code == "CW"} {
        return "CW"
    } elseif {$code == "DG"} {
        return "Digital"
    }

    return "UNKNOWN"
}

#
# Given a frequency in MHz, returns the corresponding band (70cm, 10m, 17m, etc)
# Returns UNKNOWN if the frequency does not map to a known band.
#
proc freqToBand {freq} {
    # Frequency -> band mappings taken from ARRL band plan
    if {$freq >= 420 && $freq <= 450} {
        # 70cm 420MHz - 450MHz
        return "70cm"
    } elseif {$freq >= 144 && $freq <= 148} {
        # 2m   144MHz - 148MHz
        return "2m"
    } elseif {$freq >= 50 && $freq <= 54} {
        # 6m   50MHz - 54MHz
        return "6m"
    } elseif {$freq >= 28 && $freq <= 29.7} {
        # 10m  28MHz - 29.7MHz
        return "10m"
    } elseif {$freq >= 24.89 && $freq <= 24.99} {
        # 12m  24.890MHz - 24.990MHz
        return "12m"
    } elseif {$freq >= 21 && $freq <= 21.45} {
        # 15m  21.000MHz - 21.450MHz
        return "15m"
    } elseif {$freq >= 18.068 && $freq <= 18.168} {
        # 17m  18.068MHz - 18.168MHz
        return "17m"
    } elseif {$freq >= 14 && $freq <= 14.35} {
        # 20m  14.000MHz - 14.350MHz
        return "20m"
    } elseif {$freq >= 10.1 && $freq <= 10.15} {
        # 30m  10.100MHz - 10,150MHz
        return "30m"
    } elseif {$freq >= 7 && $freq <= 7.3} {
        # 40m   7.000MHz - 7.300MHz
        return "40m"
    } elseif {$freq >= 3.5 && $freq <= 4} {
        # 80m   3.500MHz - 4.000MHz
        return  "80m"
    } elseif {$freq >= 1.8 && $freq <= 2} {
        # 160m  1.800MHz - 2.000MHz
        return "160m"
    } else {
        return "UNKNOWN"
    }
}

namespace eval ::log {
    # Stores logging verbosity 0 = error only, 1 = info, 2 = debug
    set verbosity 0
}

proc ::log::setVerbosity {lvl} {
    variable verbosity
    set verbosity $lvl
}

proc ::log::LogLine {lvl msg} {
    variable verbosity
    if {$verbosity >= $lvl} {
        puts stderr $msg
    }
}

proc ::log::debug {msg} {
    LogLine 2 "DEBUG $msg"
}

proc ::log::info {msg} {
    LogLine 1 "INFO $msg"
}

proc ::log::error {msg} {
    LogLine 0 "ERROR $msg"
}


main $argc $argv
