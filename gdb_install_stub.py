# Jonathan Foote
# jmfoote@loyola.edu

import os, sys

# Code below contains a workaround for a bug in GDB's Python API:
# os.path.abspath returns an incorrect string when this script is sourced
# from a path containing "~"
abspath = os.path.abspath(__file__)
pos = abspath.find("/~/")
if pos != -1:
    abspath = abspath[pos+1:]
abspath = os.path.expanduser(abspath)
sys.path.append(os.path.dirname(abspath))


from exploitable_lib.exploitable import ExploitableCommand

ExploitableCommand()
