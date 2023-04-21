#!/usr/bin/env tclsh
#
# A simple noweave, based on noweb, that allows us to do simple literate 
# programming.
#
# procedures
#
proc with-open-file {fname mode fp block} {
    upvar 1 $fp fpvar
    set binarymode 0
    if {[string equal [string index $mode end] b]} {
            set mode [string range $mode 0 end-1]
            set binarymode 1
    }
    set fpvar [open $fname $mode]
    if {$binarymode} {
            fconfigure $fpvar -translation binary
    }
    uplevel 1 $block
    close $fpvar
}

proc add-array-value { _arr key value } { 
    upvar 1 $_arr arr
    if {[info exists arr($key)]} {
	append arr($key) "\n$value"
    } else {
	array set arr [list $key $value]
    }
}
    
proc expand-chunks {_arr chunk indent} {
    upvar 1 $_arr arr
    if {![info exists arr($chunk)]} { 
	puts stderr "Could not find chunk $chunk"
	puts stderr "chunks found"
	foreach key [array names arr] {
	    puts stderr $key
	}
	exit 1
    }
    foreach line [split $arr($chunk) "\n"] {
        if {[regexp {^(\s*)(<<)(.*)(>>)\s*$} $line -> newIndent open newChunk close]} {
	    expand-chunks arr $newChunk $newIndent
	} else {
	    puts -nonewline "$indent"
	    puts "$line"
        }
    }
}
    
proc Usage {} { 
    global argv0
    puts stderr "$argv0 -R <chunk_name> filename"
    exit 1
}

#
# variables
# 
array set chunks {}
unset -nocomplain requestedChunk

#
# get the chuck and the filename
#

while {[llength $argv]} {
    set argv [lassign $argv[set argv {}] flag]
    switch -glob $flag {
	-R {
	    set argv [lassign $argv[set argv {}] requestedChunk]
	}
	-h - --help - -\? {
	    Usage
	}
	-- break
	-* {
	     puts stderr "unknown option $flag"
	     Usage
	}
	default {
	    set argv [list $flag {*}$argv]
	    break
	}
    }
}

#
# make sure we got a file name
#
if {[llength $argv] != 1} { 
    puts stderr "no file given, exiting"
    Usage
}
#
# make sure we got a chunk
#
set filename $argv
if {![info exists requestedChunk]} { 
    ## puts stderr "no chunk requested, default to the root chunk '*'"
    set requestedChunk "*"
}

#
# read the file and get all chunks
#
with-open-file $filename r fp { 
    set in_chunk_p 0
    unset -nocomplain chunk
    while 1 {
	gets $fp line
	if [eof $fp] break
        if {!$in_chunk_p && [regexp {(^<<)(.*)(>>=$)} $line -> open chunk close]} {
	    set in_chunk_p 1
	    continue
        }
	if {$in_chunk_p && [regexp {^(@).*(% def)?$} $line -> endchunk rest]} { 
	    set in_chunk_p 0
	    unset -nocomplain chunk
	    continue
	}
	if {$in_chunk_p} { 
	    add-array-value chunks $chunk $line 
	}
    }
}

#
# Print out the requested chunk
#
expand-chunks chunks $requestedChunk ""

exit 0

