#!/usr/bin/tclsh

# Copyright (c) 2025, Blair Kitchen
# All rights resetved.
#
# See the file "license.terms" for informatio on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.

#
# Script to print some contest related statistics from an ADIF file. Purpose
# is to help with scoring Amateur Radio Contests
#
package require Tcl 8.5
package require cmdline 1.3

source adif.tcl
package require adif 0.1

proc main {argc argv} {
    set options {
        {output.arg "" "name of the output file. stdout if ommitted"}
    }
    set usage ": adifstats.tcl \[options] file1 file2 ... \noptions:"
    if {[catch {array set params [::cmdline::getoptions argv $options $usage]} result]} {
        puts $result
        exit -1
    }

    set outChan stdout
    if {$params(output) != ""} {
        set outChan [open $params(output) "w"]
    }

    # Process each input file in order
    foreach inputFile [::cmdline::getfiles $argv false] {
        set inChan [open $inputFile "r"]

        # Initialize storage dicts
        set continentDict [dict create]

        # An empty dict indicates we've reached EOF
        set adifRecord [::adif::readNextRecord $inChan]
        while {[dict size $adifRecord] != 0} {

            # We're only processing qso records. Skip everything else
            if {[dict get $adifRecord recordType] == "qso"} {
                set recordFields [dict get $adifRecord recordData]
                
                aggregateContinentStats continentDict $recordFields

            }

            set adifRecord [::adif::readNextRecord $inChan]
        }

        printContinentStats $continentDict $outChan

        close $inChan
    }
}

#
# Given a dictionary variable to store aggregate results and an adif record,
# aggregates all of the continent and country QSOs for output by the
# printContinentStats function.
#
# This function uses the following adif fields:
#    DXCC - Used to determine the country
#    CONT - Used to determine the continent
#    FREQ - Used to determine the band
#
# If either the DXCC or CONT fields are missing, the QSO will be aggregated
# in the appropriate UNKNOWN bucket.
#
proc aggregateContinentStats {continentDictVar recordFields} {
    upvar $continentDictVar continentDict

    set continent "UNKNOWN"
    if {[dict exists $recordFields cont]} {
        set continent [dict get $recordFields cont]
    }
    set continent [contToContinent $continent]

    set dxcc "UNKNOWN"
    if {[dict exists $recordFields dxcc]} {
        set dxcc [dict get $recordFields dxcc]
    }
    set dxcc [::adif::dxccToName $dxcc]

    set band [freqToBand [dict get $recordFields freq]]

    # Increment the country level count
    set count 1
    if {[dict exists $continentDict $continent countries $dxcc $band]} {
        set count [dict get $continentDict $continent countries $dxcc $band]
        incr count
    }
    dict set continentDict $continent countries $dxcc $band $count

    # Increment the continent level count
    set count 1
    if {[dict exists $continentDict $continent summary $band]} {
        set count [dict get $continentDict $continent summary $band]
        incr count
    }
    dict set continentDict $continent summary $band $count
}

#
# Given a dictionary populated by the aggregateContinentStats function, formats
# and prints the aggregate statistics to the provided outChan.
#
# Sample output:
#
#                                 70cm 2m 6m 10m 12m 15m 17m 20m 30m 40m 60m 80m 160m
# North America                      0  0  0  25   0   5   0   0   0   0   0   0    0
#
#   United States of America         0  0  0  25   0   0   0   0   0   0   0   0    0
#   Canada                           0  0  0   0   0   5   0   0   0   0   0   0    0
#
#                                 70cm 2m 6m 10m 12m 15m 17m 20m 30m 40m 60m 80m 160m
# Europe                             0  0  0  10   0   4   0   0   0   0   0   0    0
#
#   Spain                            0  0  0   5   0   1   0   0   0   0   0   0    0
#   France                           0  0  0   4   0   3   0   0   0   0   0   0    0
#   UNKNOWN                          0  0  0   1   0   0   0   0   0   0   0   0    0
#
#                                 70cm 2m 6m 10m 12m 15m 17m 20m 30m 40m 60m 80m 160m
# UNKNOWN                            0  0  0   0   1   1   0   0   0   0   0   0    0
#
#   Belgium                          0  0  0   0   1   0   0   0   0   0   0   0    0
#   UNKNOWN                          0  0  0   0   0   1   0   0   0   0   0   0    0
#
#                                 70cm 2m 6m 10m 12m 15m 17m 20m 30m 40m 60m 80m 160m
# Totals                             0  0  0  35   1  10   0   0   0   0   0   0    0
#
proc printContinentStats {continentDict outChan} {

    # Width of the band columns
    set bandWidth 6
    # Width of the first column showing continents
    set continentWidth 45
    # Width of the country columns
    set countryPrefixWidth 4
    set countryWidth [expr {$continentWidth - $countryPrefixWidth}]

    # Generate the band header based on the list of bands being summarized
    set bandList [list 70cm 2m 6m 10m 12m 15m 17m 20m 30m 40m 60m 80m 160m]
    set bandHeader [format "% ${continentWidth}s" ""]
    foreach band $bandList {
        append bandHeader [format "% ${bandWidth}s " $band]
    }

    # Used to track the total number of QSOs in each band
    set bandTotals [dict create]
    foreach band $bandList {
        dict set bandTotals $band 0
    }

    # Iterate across the continents
    dict for {continent continentValues} $continentDict {

        # Build the continent level summary line
        puts $outChan $bandHeader
        set summaryLine [format "%-${continentWidth}s" $continent]
        foreach band $bandList {
            set count 0
            if {[dict exists $continentValues summary $band]} {
                set count [dict get $continentValues summary $band]
            }
            append summaryLine [format "%${bandWidth}d " $count]
        }
        puts $outChan $summaryLine
        puts $outChan ""


        # Iterate across the countries in each continent
        dict for {country countryValues} [dict get $continentValues countries] {

            # Build the country level summary line
            set countryLine [format "%${countryPrefixWidth}s%-${countryWidth}s" "" $country]
            foreach band $bandList {
                set count 0
                if {[dict exists $countryValues $band]} {
                    set count [dict get $countryValues $band]
                }
                append countryLine [format "%${bandWidth}d " $count]

                # Track the running total for each band
                dict incr bandTotals $band $count
            }
            puts $outChan $countryLine
        }

        puts $outChan ""
    }

    # Output the total QSOs per band
    puts $outChan $bandHeader
    set summaryLine [format "%-${continentWidth}s" "Totals"]
    foreach band $bandList {
        append summaryLine [format "%${bandWidth}d " [dict get $bandTotals $band]]
    }
    puts $outChan $summaryLine
}

#
# Given an ADIF Continent enumeration from the CONT field, returns
# the full continent name. Returns **UNKNOWN** if the enumeration is
# not recognized. This function is not case sensitive.
#
proc contToContinent {cont} {
    set cont [string tolower $cont]
    if {$cont == "na"} {
        return "NORTH AMERICA"
    } elseif {$cont == "sa"} {
        return "SOUTH AMERICA"
    } elseif {$cont == "eu" } {
        return "EUROPE"
    } elseif {$cont == "af"} {
        return "AFRICA"
    } elseif {$cont == "oc"} {
        return "OCEANIA"
    } elseif {$cont == "as"} {
        return "ASIA"
    } elseif {$cont == "an"} {
        return "ANTARCTICA"
    } else {
        return "**UNKNOWN**"
    }
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


main $argc $argv
