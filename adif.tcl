# Copyright (c) 2025, Blair Kitchen
# All rights reserved.
#
# See the file "license.terms" for informatio on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.

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

source adif.formatters.tcl
package require adif::formatters 0.1

namespace eval ::adif {
    namespace export foreachRecordInFile foreachField foreachFieldRaw createRecord recordType setField getField readNextRecord writeRecord
}

#
# Given a filename, iterates over all ADIF records in the file and executes
# the script cmd for each record. During execution, the variable var is set
# to the content of the record.
#
proc ::adif::foreachRecordInFile {var file cmd} {
    upvar $var record

    set inChan [open $file "r"]

    # An empty dict indicates we've reached EOF
    set record [readNextRecord $inChan]
    while {[dict size $record] != 0} {
        uplevel $cmd

        set record [readNextRecord $inChan]
    }

    close $inChan
}

#
# Given a record as returned from readNextRecord, iterates across all the
# the fields in the record and calls the script cmd for each record. During
# execution, the variable fieldVar is set to the name of the field and valueVar
# is set to the fields formatted value.
#
proc ::adif::foreachField {record varList cmd} {
    upvar [lindex $varList 0] field
    upvar [lindex $varList 1] value

    dict for {field value} [dict get $record recordData] {
        set value [FormatValue from $field $value]
        uplevel $cmd
    }
}

#
# Same as foreachField, except that values returned are unformatted.
#
proc ::adif::foreachFieldRaw {record varList cmd} {
    upvar [lindex $varList 0] field
    upvar [lindex $varList 1] value

    dict for {field value} [dict get $record recordData] {
        uplevel $cmd
    }
}

#
# Given a record type (header or qso), creates and returns a new record of the
# corresponding type. The record is suitable for passing to setField, getField,
# writeRecord, etc.
#
proc ::adif::createRecord {recordType} {
    set recordType [string tolower $recordType]

    if {$recordType != "header" && $recordType != "qso"} {
        error "unknown recordType '$recordType'"
    }
    return [dict create recordType $recordType recordData [dict create]]
}

#
# Given a record as returned by the readNextRecord function, returns
# the type of said record, either qso or header.
#
proc ::adif::recordType {record} {
    return [dict get $record recordType]
}

#
# Given the name of a variable holding a record as returned by the
# readNextRecord function, a field name, and a value, sets the
# specified field to the value and returns the record contents.
#
# By default, if a corresponding formatter exists in the ::adif::formatters
# namespace, then the formatter is called to convert the value from a human
# readable value to the corresponding ADIF enumeration value.  This behavior
# may be disabled by appending '.raw' to the field name. For example, passing
# "dxcc" as the field name will convert the value before writing, while passing
# "dxcc.raw" as the field name will write the raw value of the field without
# invoking any formatters.
#
# NOTE: This function serves as a wrapper around dict set and is intended to
#       offer additional functionality around ADIF records, including
#       formatting and translating values from human readable formats.
#
proc ::adif::setField {var field value} {
    upvar $var record

    set field [string tolower $field]

    # The field name may have a format modifier appended
    foreach {field formatModifier} [split $field .] {}

    # Lookup any available formatter for this field
    if {$formatModifier != "raw"} {
        set value [FormatValue to $field $value]
    }

    return [dict set record recordData $field $value]
}

#
# Given a record as returned by the readNextRecord function and a field name,
# returns the value of said field. Requesting a field that does not exist
# results in defaultValue being returned.
#
# By default, if a corresponding formatter exists in the ::adif::formatters
# namespace, then the formatter is called to convert the raw value of the
# field into a human readable value before returning. This behavior may be
# disabled by appending '.raw' to the field name. For example, passing "dxcc"
# as the field name will return the formatted dxcc value, while passing
# "dxcc.raw" as the field name will return the raw value of the field as it
# appears in the ADIF record, without formatting.
#
# NOTE: This function serves as a wrapper around dict get and is intended to
#       offer additional functionality around ADIF records, including
#       formatting and translating values into human readable formats.
#
proc ::adif::getField {record field {defaultValue ""}} {
    set field [string tolower $field]

    # The field name may have a format modifier appended
    foreach {field formatModifier} [split $field .] {}

    # If the field is missing, just return an empty string
    if {![dict exists $record recordData $field]} {
        return $defaultValue
    }

    set value [dict get $record recordData $field]

    # Lookup any available formatter for this field
    if {$formatModifier != "raw"} {
        set value [FormatValue from $field $value]
    }

    return $value
}

#
# Given a direction (to|from), a field, and a value, returns the formatted
# value. If no formatter is found, returns the value as-is
#
proc ::adif::FormatValue {direction field value} {
    set formatterName formatters::$field.$direction
    if {[info commands $formatterName] != ""} {
        set value [$formatterName $value]
    }
    return $value
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
# NOTE: While the function returns a dict, it is recommended you DO NOT access the dict
#       directly, as the format is liable to change. Instead, use the recordType, getField,
#       setField, and other helper functions to access the record data.
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
        set field [string trim $field]

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
            set record [createRecord $recordType]
            dict set record recordData $fieldValues
            return $record
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
        puts $chan "<$name:$valueLen>$value"
    }

    if {[dict get $record recordType] == "qso"} {
        puts $chan "<EOR>"
    } else {
        puts $chan "<EOH>"
    }
    puts $chan ""
}
