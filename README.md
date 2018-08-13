GDB 'exploitable' plugin
====

Jonathan Foote

jmfoote@loyola.edu

15 April 2015

Requirements 
====

- Compatible x86/x86_64/ARM/MIPS Linux
- Compatible GDB 7.2 or later
- Python 2.7 or later (for triage.py)

      
The 'exploitable' plugin (exploitable/exploitable.py)
====

'exploitable' is a GDB extension that classifies Linux application bugs by severity. The extension inspects the state of a Linux application that has crashed and outputs a summary of how difficult it might be for an attacker to exploit the underlying software bug to gain control of the system. The extension can be used to prioritize bugs for software developers so that they can address the most severe ones first. 

The extension implements a GDB command called 'exploitable'. The command uses heuristics to describe the exploitability of the state of the application that is currently being debugged in GDB. The command is designed to be used on Linux platforms and versions of GDB that include the GDB Python API. Note that the command will not operate correctly on core file targets at this time.

WARNING: This is an engineering tool. It has not been exhaustively tested, and has not been executed on many flavors of Linux! Please read and understand the classification rules (lib/rules.py) before use and modify the source code to suit your specific testing needs if necessary.

Usage
----

### Global installation and usage

1. Optionally, run integration tests:

        $ python setup.py test

2. Install script to GDB data directory (probably as root)

        # python setup.py install

3. Run the command

        (gdb) exploitable

### Local usage
1. Copy all files in this directory and its sub-directories to a sub-directory that is accessible from GDB

2. Source the exploitable file as a script and run a command

        (gdb) source my-exploitable-dir/exploitable.py
        (gdb) exploitable
       
In many cases exploitable makes guesses and calculates values based on GDB's stack unwind. The extension will work best if GDB can find the debug symbols for binaries, especially libc. 

Note that the extension's classification capability is significantly degraded when run in a GDB session with a core file target. When GDB is run against a core file, much of the information that the extension uses for classification is not present via conventional GDB APIs.

Testing 
----

### Smoke testing

This project includes test cases (tests/) that can be used as a starting point for testing the 'exploitable' command on new Linux platforms. A Makefile is included. Note that test case filenames generally correspond to the most exploitabile tag that should be applied to the test case, however, because Linux platforms handle errors differently, an exact correspondence will not exist for all of the test cases on most Linux platforms. 

A few unit tests have been implemented in lib/gdb_wrapper/tests/x86\_unit\_tests.py. unit\_tests.py is  meant to be invoked from GDB -- see comments in the file for details.

### Integration testing

Integration tests for x86 and ARM platforms are located in test/x86.sh and test/arm.sh, respectively. These tests are designed for use with travis-ci.org, but can (and should) be run locally on an up-to-date Ubuntu x86_64 any time functional changes are made to the code. Note that, if not modified, arm.sh requires access to a private AWS S3 bucket to install dependencies. Please contact the author if you require access to the S3 bucket.

To run the integration x86 tests, try this from the project root directory:

        $ ./tests/x86.sh

Note that these tests are quite fragile and will (hopefully improve over time).

#### Tested platforms

At the time of this writing integration tests pass on the following platforms:

- Ubuntu 13.10 32-bit, GDB 7.2
- Ubuntu 13.10 64-bit, GDB 7.4
- Ubuntu 13.10 64-bit, GDB 7.6
- Travis-ci Ubuntu 64-bit, GDB 7.4

The authors of the GDB Python API tend to break backwards compatibility regularly, so beware.

Internals Overview 
----

exploitable runs in GDB's Python interpreter (which depends on the Python C API) and uses GDB's Python API. For details, see:
http://sourceware.org/gdb/onlinedocs/gdb/Python-API.html

exploitable iterates over a list of ordered "rules" (lib/rules.py) to generate a Classification (lib/classifier.py). If the state of the application running in GDB matches a rule, exploitable adds a corresponding "tag" to the Classification. The result of an exploitable invocation is a Classification-- either printed to the GDB's stdout or stored to a pickle file, depending on command parameters. 

The entry point for the GDB command is defined in exploitable.py. Iteration over the rules is implemented by a Classifier object (lib/classifier.py). The methods that determine whether a rule matches or not are contained in per-platform "analyzers" (lib/analyzers/). The state of the application is queried via a set of GDB API wrapper objects and methods (see lib/gdb_wrapper/x86.py for details). A Classification (lib/classifier.py) retains attributes for the "most exploitable" (lowest ordered) tag (matching rule), but it also includes an ordered list of all other matching tags.

Classification rule definitions, located in lib/rules.py, can be re-prioritized by simple cut/paste.

Contributing
----

Please contribute your changes, fixes, and issues to the master branch at https://github.com/jfoote/exploitable ! To help things go smoothly, please ensure that the integration tests (see test/ in the home directory) pass before you submit your code. Feel free to change the integration tests themselves if you are fixing bugs or adding features. Feel free to contact the author (jmfoote@loyola.edu) if you have any questions or feedback.

triage.py
====

This package consists of a triage script and a GNU Debugger (GDB) extension named 'exploitable'. The triage script is a simple batch wrapper for the 'exploitable' GDB extension. The triage script is designed to prioritize bugs for software developers so that they can address the most severe ones first. For more information on the 'exploitable' GDB extension, see the 'exploitable' section below.

The triage script automates invocations of GDB and the 'exploitable' GDB extension. The script invokes a target application one or more times via GDB. Each invocation includes execution of the exploitable command. Results of the exploitable command are accumulated and a summary is printed to stdout.  

WARNING: The triage script was written to address some specific testing needs, so it is not particularly robust or extensible. The script is being distributed as a starting point and example for writing a custom wrapper for the 'exploitable' extension.

In practice the triage script is meant to run an application with a set of crashing inputs that have been discovered via other means. If an application invocation does not cause GDB to break, the triage script will hang (CTRL-C to stop). 

Note that some output from the application under test may be printed to the console as the triage script runs (particularly output from libc_message). Also note that the 'exploitable' extension will not operate correctly on core file targets at this time.

Usage 
----

The triage script is designed to be invoked from this directory.

### Print help

1. From this directory, invoke triage

        python triage.py --help

### Running included exploitable tests (Hello exploitable!)

1. Build exploitable tests

        cd exploitable/tests && make && cd ../..

2. Invoke triage with the tests as arguments

        python triage.py \$sub `find exploitable/tests/bin -type f`

3. Cleanup test binaries

        cd exploitable/tests && make clean && cd ../..

### Example application usage

1. Invoke triage with application and crashing inputs as arguments. For example:

        python triage.py "jasper --input \$sub --output /dev/null" `find /mnt/foo/crashers -type f`

This example will invoke japser for each file in /mnt/foo/crashers. 

