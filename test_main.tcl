source adif.tcl
package require adif 0.1

proc main {argc argv} {
    set fileName [lindex $argv 0]
    set inChan [open $fileName "r"]
    set outChan [open "sample.adi" "w"]

    puts "reading from $fileName"
    set record [::adif::readNextRecord $inChan]
    while {[dict size $record] != 0} {
        puts "found record: $record"
        puts ""
        puts "writing record"
        ::adif::writeRecord $outChan $record
        puts ""

        set record [::adif::readNextRecord $inChan]
    }

    puts "done reading from $fileName"
    close $inChan
    close $outChan
}

main $argc $argv
