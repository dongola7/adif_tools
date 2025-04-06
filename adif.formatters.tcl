# Copyright (c) 2025, Blair Kitchen
# All rights reserved.
#
# See the file "license.terms" for informatio on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.

#
# This Tcl package supports the adif package and provides a variety of
# formatters for converting to/from values in ADIF format into human
# readable values.
#
package require Tcl 8.5
package require fileutil 1.14

package provide adif::formatters 0.1

#
# Formatters for ADIF fields should be defined in the following namespace. The
# naming convention is important as the specific convention is used by the adif
# package to locate a formatter for automatic conversion.
#
# The format is as follows: <adif-field>.<to|from> where:
#   * adif-field - Is the lowercase name of the ADIF field
#   * to|from - 'to' indicates the function converts from human readable to
#               ADIF format, while 'from' indicates the function converts from
#               ADIF format to human readable.
#
# Example: A function named 'dxcc.from' converts the DXCC field from it's
#          numerical value to a human readable value. 'dxcc.to' would convert
#          from the human readable value to the original ADIF value.
#
# All functions should accept a single input: the value to be converted.
# The output should be either the converted value, or, if no conversion is
# possible, the original input value.
#
namespace eval ::adif::formatters {

    # Helper function used to read format maps from a text file and generate
    # the corresponding maps converting from the ADIF value to the human
    # readable value and back. Both conversions are stored in lowercase
    # so that lookups may be case insensitive.
    proc MakeFormatMaps {fromMap toMap fileName} {
        variable $fromMap
        variable $toMap

        fileutil::foreachLine line [file join [file dirname [info script]] $fileName] {
            set line [string trim $line]

            if {$line == ""} {
                # Skip empty lines
                continue
            } elseif {[string index $line 0] == "#"} {
                # Skip comments
                continue
            }

            # Parse the line into it's key and value and setup the maps
            foreach {key value} $line {
                set ${fromMap}([string tolower $key]) $value
                set ${toMap}([string tolower $value]) $key
            }
        }
        
    }

    #
    # Helper function used to perform simple, case insensitive lookups
    # of a key in an array. If the key exists in the array, the corresponding
    # value is returned. Otherwise, the key itself is returned.
    #
    proc SimpleLookup {lookupArray key} {
        variable $lookupArray

        set key [string tolower $key]

        if {[info exists ${lookupArray}($key)]} {
            return [set ${lookupArray}($key)]
        } else {
            return $key
        }
    }

    #
    # Basic formatters are below
    #

    MakeFormatMaps DxccFrom DxccTo "dxcc.txt"
    proc dxcc.from {dxcc} { SimpleLookup DxccFrom $dxcc }
    proc dxcc.to {dxcc} { SimpleLookup DxccTo $dxcc }

    MakeFormatMaps ContFrom ContTo "cont.txt"
    proc cont.from {cont} { SimpleLookup ContFrom $cont }
    proc cont.to {cont} { SimpleLookup ContTo $cont }
}
