#!/bin/bash
#
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

# *****************************************************************************
# Description:
#
# This script performs integration testing of the GDB 'exploitable' plugin
# for x86 targets. It is designed to be executed from the base directory
# of the 'exploitable' project, though another directory may be specified
# via the TRAVIS_BUILD_DIR environment variable. It isn't pretty, but it is
# designed to work both locally and with travis-ci.org VMs.
#
# Functional overview: 
#
# This script downloads test dependencies and builds the test
# cases supplied in the exploitable repo. The script then runs triage.py 
# over all of the test cases in the and stores the result to a JSON file.
# Finally, the result is compared to an expected result.
#
# Jonathan Foote
# jmfoote@loyola.edu

set -e # exit if any simple command returns non-zero
set -x # this script is not polished/user-friendly, so we debug by default

PROJECT_DIR=${TRAVIS_BUILD_DIR:-$(pwd)}
BUILD_DIR=$PROJECT_DIR/build

clone() {
    # get project code (travis-ci does this automagically)
    git clone https://github.com/jfoote/exploitable
}

get_deps() {

    # install dependencies 
    sudo apt-get update
    sudo apt-get install gdb gcc python --yes # essentials for x86
    sudo apt-get install execstack --yes # x86 testing 
}

build() {
    mkdir -p $BUILD_DIR

    # build test cases
    pushd ${PROJECT_DIR}/exploitable/tests
    make
    popd
}

run_test() {
    pushd ${PROJECT_DIR}
    export PYTHONPATH=$PYTHONPATH:`pwd`/exploitable
    failed=""
    set +e # disable fail-on-nonzero for tests
    set +x
    echo "verbose script debugging disabled"

    # check each test cases against expected
    for f in `find exploitable/tests/bin -type f`
    do
        cmd="gdb --batch -ex \"source exploitable/exploitable.py\" -ex run -ex \"exploitable -v -p ${BUILD_DIR}/triage.pkl\" --args $f "
        eval $cmd &> /dev/null
        # command below compares only short_desc fields
        result=$(python -c "import sys, pickle, json; expected = json.load(open('${PROJECT_DIR}/test/x86-expected.json')); expected = [i for i in expected if i[0] == '$f'][0][1]['short_desc']; result = pickle.load(open('${BUILD_DIR}/triage.pkl'))['short_desc']; print('result=%s expected=%s' % (result, expected)); sys.exit(not result in expected)")
        if [[ "$?" -ne "0" ]] ; then
            failed="$failed$f:
                $result
                cmd=$cmd
            "
        fi
        echo "`basename $f`: $result"
    done
    popd
    if [[ $failed != "" ]] ; then
        echo ""
        echo "TESTS FAILED:"
        echo "$failed"
        echo "Tests failed, exiting."
        exit -1
    fi
    set -x
    set -e # re-enable fail-on-nonzero
    echo "verbose script debugging enabled"
}

clean() {
    # clean up 
    rm -rf ${BUILD_DIR}
    pushd ${PROJECT_DIR}/exploitable/tests && make clean && popd
}

echo "starting"

# Run end-to-end test, or a a list of functions if the user has specified them
if [[ -z $1 ]] ; then
  get_deps
  build
  run_test
  clean
else
  for cmd in $@
  do
    $cmd
  done
fi

echo "done!"
exit 0
