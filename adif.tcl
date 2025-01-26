#
# This Tcl package provides basic parsing and writing of ADIF formatted records
# for use in Amateur Radio Logging. It's loosely based on the spec at
# https://adif.org, but does not fully implement all aspects. For example, user
# defined fields and data types are not supported.
#
# This is really a personal project intended as a WIP and meeting whatever my
# needs are at the time.
#
package require Tcl 8.5

package provide adif 0.1

namespace eval ::adif {
}

#
# Given a channel containing ADIF formatted data, this function will return the
# next record in the channel. Note the function will block until a complete record
# is available or EOF is returned.
#
# If a record is found, the function will return a dict containing two keys:
#    recordType - The type of record being returned. Possible values are "header" or "qso"
#    recordData - A nested dict where with the keys being record field names and the values
#                 being the corresponding field values. Because field names in ADIF are
#                 case insensitive, all field names will be normalized in lower case.
#
# If EOF is detected before a complete record is found, an empty dict is returned
#
proc ::adif::readNextRecord {chan} {
    set fieldValues [dict create]

    while {![eof $chan]} {
        # Read until the beginning of a field is found
        ReadUntil $chan "<"

        # Read the field name and length
        set field [ReadUntil $chan ">"]

        # If field name is empty, return an empty dict, as we hit EOF or some
        # other error.
        if {$field == ""} {
            return [dict create]
        }

        # Normalize field names to lowercase
        set field [string tolower $field]

        # If we've found the end of a header or record, return the fields values
        # found so far along with the record type
        if {$field == "eoh" || $field == "eor"} {
            if {$field == "eoh"} {
                set recordType "header"
            } else {
                set recordType "qso"
            }
            return [dict create recordType $recordType recordData $fieldValues]
        }

        # We have a new record field. Parse the name/length, read the value, and
        # store in the set to be returned
        lassign [split $field ":"] fieldName fieldLength
        set fieldValue [read $chan $fieldLength]
        dict set fieldValues $fieldName $fieldValue
    }

    # If we're here, it means we've hit EOF. Partial records are discarded and
    # we return an empty dict
    return [dict create]
}

#
# Given a channel, reads until the specified character is found
# Returns everything up to, but excluding said character.
#
proc ::adif::ReadUntil {chan searchChar} {
    set char ""
    set result ""
    while {$char != $searchChar && ![eof $chan]} {
        append result $char
        set char [read $chan 1]
    }

    return $result
}

#
# Given a dict of the same format returned by ::adif::readNextRecord,
# converts the record into ADIF format and writes the result to the specified
# channel. All field names are normalized to uppercase when written to the
# channel.
#
proc ::adif::writeRecord {chan record} {
    set fieldValues [dict get $record recordData]

    dict for {name value} $fieldValues {
        set name [string toupper $name]
        set valueLen [string length $value]
        puts $chan "<$name:$valueLen>$value "
    }

    if {[dict get $record recordType] == "qso"} {
        puts $chan "<EOR>"
    } else {
        puts $chan "<EOH>"
    }
    puts $chan ""
}
