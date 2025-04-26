#!/bin/sh
# the next line restarts using tclsh \
exec tclsh "$0" "$@"

# Copyright (c) 2025, Blair Kitchen
# All rights reserved.
#
# See the file "license.terms" for informatio on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.

#
# This script is used to convert ADIF formatted files to Cabrillo format.
#
# Note it's only been tested with ADIF files from MacLoggerDX. Adjustments may be needed
# for other logging programs. I'll try to keep it updated as I gain more experience.
#
package require Tcl 9.0
package require cmdline 1.3

source [file join [file dirname [file normalize [info script]]] adif.tcl]
package require adif 0.1

proc main {argc argv} {
    set options {
        {output.arg "" "name of the output file. stdout if ommitted"}
        {txexch.arg "rst_sent stx stx_string" "list of ADIF fields, in order, included in the tx exchange"}
        {rxexch.arg "rst_rcvd srx srx_string" "list of ADIF fields, in order, included in the rx exchange"}
    }
    set usage ": adif2cabrillo.tcl \[options] file1 file2 ... \noptions:"
    if {[catch {array set params [::cmdline::getoptions argv $options $usage]} result]} {
        puts $result
        exit -1
    }

    set outChan stdout
    if {$params(output) != ""} {
        set outChan [open $params(output) "w"]
    }

    set txExchFields [split [string tolower $params(txexch)]]
    set rxExchFields [split [string tolower $params(rxexch)]]

    # Process each input file in order
    foreach inputFile [::cmdline::getfiles $argv false] {
        ::adif::foreachRecordInFile adifRecord $inputFile {

            # We're only converting qso records. Skip everything else
            if {[::adif::recordType $adifRecord] == "qso"} {
                puts $outChan [adifToCabrillo $txExchFields $rxExchFields $adifRecord]
            }

        }
    }
}

#
# Given a list of ADIF fields for the tx and rx portions of the contest exchange
# and an ::adif dict representing a QSO record, returns a string QSO record in
# Cabrillo format suitable for writing to a file.
#
# The list of ADIF fields representing the exchanges are concatenated, in order,
# into a single space delimited string. Any missing fields are ignored.
#
# Example Cabrillo record (from https://wwrof.org/cabrillo/cabrillo-qso-data/)
#                              --------info sent------- -------info rcvd--------
#QSO:  freq mo date       time call          rst exch   call          rst exch   t
#QSO: ***** ** yyyy-mm-dd nnnn ************* nnn ****** ************* nnn ****** n
#QSO:  3799 PH 1999-03-06 0711 HC8N           59 700    W1AW           59 CT     0
#QSO:  3799 PH 1999-03-06 0712 HC8N           59 700    N5KO           59 CA     0
#
proc adifToCabrillo {txExchFields rxExchFields adifRecord} {
    set cabrillo "QSO: "

    # Frequency in ADIF is MHz, but in Cabrillo is rounded to nearest KHz
    set freq [adif::getField $adifRecord freq]
    set freq [expr {round($freq * 1000)}]
    append cabrillo [format "%5d" $freq] " "

    # Generate the Cabrillo mode field
    set mode [adifToCabrilloMode [adif::getField $adifRecord mode]]
    append cabrillo $mode " "

    # Generate the date and time portions of the record (UTC)
    set timestamp "[adif::getField $adifRecord qso_date] [adif::getField $adifRecord time_on]"
    set timestamp [clock scan $timestamp -timezone :UTC -format "%Y%m%d %H%M%S"]
    set date [clock format $timestamp -timezone :UTC -format "%Y-%m-%d"]
    set time [clock format $timestamp -timezone :UTC -format "%H%M"]
    append cabrillo $date " " $time " "

    # Generate the transmitted portion of the record
    append cabrillo [format "%- 14s" [adif::getField $adifRecord operator]] " "
    set txExch ""
    foreach fieldName $txExchFields {
        set value [adif::getField $adifRecord $fieldName]
        if {$value != ""} {
            append txExch $value " "
        }
    }
    append cabrillo [format "%- 10s" $txExch]

    # Generate the received portion of the record
    append cabrillo [format "%- 14s" [adif::getField $adifRecord call]] " "
    set rxExch ""
    foreach fieldName $rxExchFields {
        set value [adif::getField $adifRecord $fieldName]
        if {$value != ""} {
            append rxExch $value " "
        }
    }
    append cabrillo [format "%- 10s" $rxExch]

    return $cabrillo
}

#
# Maps ADIF modes to their corresponding Cabrillo modes. Most of these
# are my best guess, so adjust as needed.
#
array set adifModeMap {
    AM PH
    ARDOP DG
    ATV DG
    CHIP DG
    CLO DG
    CONTESTI ??
    CW CW
    DIGITALVOICE PH
    DOMINO DG
    DYNAMIC DG
    FAX DG
    FM PH
    FSK441 DG
    FT8 DG
    HELL DG
    ISCAT DG
    JT4 DG
    JT6M DG
    JT9 DG
    JT44 DG
    JT65 DG
    MFSK DG
    MSK144 DG
    MT63 DG
    OLIVIA DG
    OPERA DG
    PAC DG
    PAX DG
    PKT DG
    PSK DG
    PSK2K DG
    Q15 DG
    QRA64 DG
    ROS DG
    RTTY RY
    RTTYM RY
    SSB PH
    SSTV DG
    T10 DG
    THOR DG
    THRB DG
    TOR DG
    V4 DG
    VOI DG
    WINMOR DG
    WSPR DG
}

#
# Given an ADIF mode, returns the corresponding Cabrillo mode
#
proc adifToCabrilloMode {mode} {
    global adifModeMap
    return $adifModeMap($mode)
}

main $argc $argv
