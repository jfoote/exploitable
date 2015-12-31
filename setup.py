#!/usr/bin/env python

# The MIT License (MIT)
#
# Copyright (c) 2013 Jonathan Foote
#           (c) 2015 rc0r
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

'''
A distutils-compatible setup.py script.

This script includes a hack to support both virtualenv and standard
installation paths on Ubuntu 15.04. See the following URL for more information:
    https://github.com/jfoote/exploitable/pull/34#issuecomment-168158763
'''

from setuptools.command.bdist_egg import bdist_egg
from setuptools import setup, Command, find_packages

import os
import subprocess
import shlex


class CustomBdistEgg(bdist_egg):
    """
    Our custom "install" class that overrides the default setuptools
    bdist_egg procedure. We use bdist_egg here because in contrary
    to a custom install it also gets called when setup is run from
    easy_install.
    """
    def run(self):
        # run default setup procedure
        bdist_egg.run(self)

        import sys

        # Check whether setup.py is run from inside a virtualenv and get the
        # appropriate install location for exploitable.py.
        if hasattr(sys, 'real_prefix'):
            # Inside virtualenv:
            #   Use Python standard library location.
            from distutils.sysconfig import get_python_lib
            install_base_path = get_python_lib()
        else:
            # Not inside virtualenv, operating on a real Python environment:
            #   Use location for Python site-specific, platform-specific files.
            from sysconfig import get_path
            install_base_path = get_path('platlib')

        path_to_exploitable = os.path.join(install_base_path,
                                           os.path.basename(self.egg_output),
                                           'exploitable',
                                           'exploitable.py')
        print('\x1b[0;32m**********************************************')
        print(' Install complete! Source exploitable.py from')
        print(' your .gdbinit to make it available in GDB:')
        print('')
        print(' \x1b[1;37mecho \"source %s\" >> ~/.gdbinit\x1b[0;32m' % path_to_exploitable)
        print('**********************************************\x1b[0m')


class TestCommand(Command):
    """
    Custom test command.
    """
    description = 'Run exploitable tests.'
    user_options = []

    def initialize_options(self):
        pass

    def finalize_options(self):
        pass

    def run(self):
        print("testing for x86, for ARM and more args, see scripts in test/ dir")
        run("test/x86.sh build run_test clean")
        print("done")


def run(cmd):
    try:
        print(cmd)
        subprocess.check_call(shlex.split(cmd))
    except subprocess.CalledProcessError:
        pass


dependencies = []

setup(
    name='exploitable',
    version='1.32',
    url='https://github.com/jfoote/exploitable',
    author='Jonathan Foote',
    author_email='jmfoote@loyola.edu',
    description='The \'exploitable\' GDB plugin.',
    long_description=open('./README.md', 'r').read(),
    requires=dependencies,
    packages=find_packages(),
    platforms=[
        'Any'
    ],
    cmdclass={
        'bdist_egg': CustomBdistEgg,
        'test': TestCommand
    }
)
