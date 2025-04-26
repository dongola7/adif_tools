#!/bin/sh
# the next line restarts using tclsh \
exec tclsh "$0" "$@"

# Copyright (c) 2025, Blair Kitchen
# All rights reserved.
#
# See the file "license.terms" for informatio on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.

package require Tcl 9.0
package require tcltest 2.3

::tcltest::configure -testdir [file dirname [file normalize [info script]]]
::tcltest::configure {*}$argv

::tcltest::runAllTests
