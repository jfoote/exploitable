CERT post-mortem triage tools version 1.04
October 4, 2012

===== Requirements =====

Compatible 32-bit or 64-bit Linux 
GDB 7.2 or later
Python 2.6 or later

===== About =====

The CERT post-mortem triage tools consist of a triage script and a GNU Debugger (GDB) extension named 'exploitable'. The triage script is a simple batch wrapper for the 'exploitable' GDB extension. The triage script is designed to prioritize bugs for software developers so that they can address the most severe ones first. For more information on the 'exploitable' GDB extension, see exploitable/readme.txt.

The triage script automates invocations of GDB and the 'exploitable' GDB extension. The script invokes a target application one or more times via GDB. Each invocation includes execution of the exploitable command. Results of the exploitable command are accumulated and a summary is printed to stdout.  

WARNING: The triage script was written to address some specific testing needs at CERT, so it is not particularly robust or extensible. The script is being distributed as a starting point and example for writing a custom wrapper for the 'exploitable' extension.

In practice the triage script is meant to run an application with a set of crashing inputs that have been discovered via other means. If an application invocation does not cause GDB to break, the triage script will hang (CTRL-C to stop). 

Note that some output from the application under test may be printed to the console as the triage script runs (particularly output from libc_message). Also note that the 'exploitable' extension will not operate correctly on core file targets at this time.

===== Usage =====

The triage script is designed to be invoked from this directory.

Print help
  1. From this directory, invoke triage
       python triage.py --help
Running exploitable tests
  1. Build exploitable tests
       cd exploitable/tests && make && cd ../..
  2. Invoke triage with the tests as arguments
       python triage.py \$sub `find exploitable/tests/bin -type f`
  3. Cleanup test binaries
       cd exploitable/tests && make clean && cd ../..
Example application usage
  1. Invoke triage with application and crashing inputs as arguments
       ex: python triage.py "jasper --input \$sub --output /dev/null" \
           `find /mnt/foo/crashers -type f`
       The example will invoke japser for each file in /mnt/foo/crashers. 
       
