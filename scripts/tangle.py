#!/usr/bin/env python3

import sys
import re
import os

#
# procedures/functions/what not
#
def Out(*args,**kwargs):
    """
    Write to standard error. The input string is args.
    kwargs allow for additional arguments to the print statement,
    perhaps, 'end="end of error!'"
    """
    print(*args,file=sys.stderr,**kwargs)

def Usage():
    Out("Usage " + progname)
    Out("\nOptions")
    Out("-R chunk         - chunk to pull out defaults to *")
    Out("\nArguments") 
    Out("markdown_file    - file to check for chunks. Required\n")
    sys.exit(1)

def expandChunks(chunk, indent):
    """
    Given a chunk, output it.
    If the chunk is not found, output a list of all available chunks.
    """
    if chunk not in chunks.keys():
        Out(chunk + " not found, but the following are:")
        for key in chunks.keys():
            Out(" * " + key)
        sys.exit(1)

    for line in chunks[chunk]:
        match = re.match("(\s*)<<" + "([^>]+)" + ">>\s*$", line)
        if match:
            expandChunks(match.group(2),match.group(1))
        else:
            print(indent + line)

#
# Main
#

chunks = {}
requestedChunk="*"
progname = sys.argv.pop(0)

while len(sys.argv) > 0:
    flag = sys.argv.pop(0)
    if flag == "-R":
        requestedChunk = sys.argv.pop(0)
    elif flag == "-h" or flag == "--help" or flag == "-\?":
        Usage()
    elif flag == "--":
        break
    elif re.search(r'^\-',flag):
        Out("unknown option " + flag)
        Usage()
    else:
        break

if len(sys.argv) != 0:
    Out("too many arugments, we can only use one file.")
    Usage()

filename = flag

with open(filename) as fp:
    in_chunk_p = False
    chunk = None
    while True:
        line = fp.readline()
        if not line: break

        match = re.match("<<([^>]+)" + ">>=", line)
        if not in_chunk_p and match:
            in_chunk_p = True
            chunk = match.group(1)
            if not chunk in chucks.keys()
                chunks[chunk] = []
            continue

        match = re.match("@", line)
        if in_chunk_p and match:
            in_chunk_p = False
            chunk = None
            continue

        if in_chunk_p: 
            chunks[chunk].append(line.rstrip())

expandChunks(requestedChunk,"")
