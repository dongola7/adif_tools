package require Tcl 8.5

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
proc ::adif::nextRecord {chan} {
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
            return [dict create recordType $field recordData $fieldValues]
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

proc main {argc argv} {
    set fileName [lindex $argv 0]
    set inChan [open $fileName "r"]

    puts "reading from $fileName"
    set record [::adif::nextRecord $inChan]
    while {[dict size $record] != 0} {
        puts "found record: $record"
        set record [::adif::nextRecord $inChan]
    }

    puts "done reading from $fileName"
    close $inChan
}

main $argc $argv
