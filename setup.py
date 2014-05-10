#!/usr/bin/env python

# The MIT License (MIT)
# 
# Copyright (c) 2013 Jonathan Foote
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy of
# this software and associated documentation files (the "Software"), to deal in
# the Software without restriction, including without limitation the rights to
# use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
# the Software, and to permit persons to whom the Software is furnished to do so,
# subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
# FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
# COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
# IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
# CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

import os
from optparse import OptionParser

def run(cmd):
    import subprocess, shlex
    print cmd
    subprocess.check_call(shlex.split(cmd))

if __name__ == "__main__":
    usage = "usage: %prog install|uninstall|test [path]"
    desc = "[Un]installs exploitable gdb plugin to PATH, or GDB data dir if no "  +\
           "path is specified."
        
    op = OptionParser(description=desc, usage=usage)

    (opts, args) = op.parse_args()
    if len(args) < 1:
        op.error("wrong number of arguments")
    if len(args) == 1:
        import subprocess, shlex, re
        path = subprocess.check_output(shlex.split(
            "gdb --batch -ex 'show data-directory'")).strip()
        match = re.match("^.*\"(.*)\".*$", path)
        if not match:
            raise Exception("GDB data directory parse command failed, "
                    "make sure GDB is installed and try specifying a path "
                    "manually")
        path = match.groups()[0]
    elif len(args) == 2:
        path = args[1]
    path = os.path.join(path, 'python', 'gdb', 'command')
    print "Target path is %s" % path
    if args[0] == "install":
        from shutil import copy, move
        run("cp -R exploitable/ %s/exploitable_lib" % path)
        run("touch %s/exploitable_lib/__init__.py" % path)
        run("cp gdb_install_stub.py %s/exploitable.py" % path)
    elif args[0] == "uninstall":
        run("rm %s/exploitable.py" % path)
        run("rm -rf %s/exploitable_lib" % path)
    elif args[0] == "test":
        if len(args) == 2:
            op.error("y u specify path with test?")
        print "testing for x86, for ARM and more args, see scripts in test/ dir"
        run("test/x86.sh build run_test clean")
        print "done"
    else:
        op.error("first arg is incorrect")
