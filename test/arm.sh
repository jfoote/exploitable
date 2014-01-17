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
# for ARM targets. It is designed to be executed from the base directory
# of the 'exploitable' project, though another directory may be specified
# via the TRAVIS_BUILD_DIR environment variable. It isn't pretty, but it is
# designed to work both locally and with travis-ci.org VMs.
#
# WARNING: This script relies on access to a private AWS S3 bucket to download 
# a custom ARM compiler. Access is granted via the conventional AWS key
# environment variables. If you plan to use or fork this script such that 
# the test machine doens't have access to the bucket, you'll need to give it 
# access to a bucket with functionally equivalent contents or edit the 
# respective portion of this script.
# 
# WARNING: ARM support for exploitable was graciously contributed by a user, 
# but the results are not totally correct. Thus, this script simply ensures
# that results are consistent. Please help resolve this issue!
#
# Functional overview: 
#
# This script downloads test dependencies including qemu-system 
# (a bare-metal ARM emulator), the QEMU test ARM image (a linux OS), 
# jimdb (a GDB client with ARM target and Python scripting support), and 
# custom ARM compiler. The script then builds the exploitable test cases
# using the custom ARM compiler and modifies the initrd for the ARM image to
# include the test cases and a gdbserver. An ARM virtual machine is then 
# launched with the modified ARM image via QEMU. The VM is configured to 
# run a GDB server on boot and wait for connections. Once the VM is waiting
# for connections, the script runs triage.py over all of the test cases 
# (making use of several commandline options), connecting to the gdbserver
# to run a classify each test case in the ARM environment. Finally, the 
# result of the triage.py run is stored to a JSON file and compared to 
# an expected result.
#
# Jonathan Foote
# jmfoote@loyola.edu

set -e # exit if any simple command returns non-zero
set -x # this script is not polished/user-friendly, so we debug by default

PROJECT_DIR=${TRAVIS_BUILD_DIR:-$(pwd)}
BUILD_DIR=$PROJECT_DIR/build

clone() {
    # get project code (travis-ci does this automagically)
    git clone https://github.com/jfoote/exploitable -b integration
}

get_deps() {
    # install dependencies 
    sudo apt-get update
    sudo apt-get install gdb gcc python gcc-multilib g++-multilib --yes # essentials for x86
    #sudo apt-get install git vim psmisc --yes # dev tools
    sudo apt-get install qemu qemu-system python-pip --yes # arm testing 
    sudo pip install boto # accessing S3

    mkdir -p $BUILD_DIR
    pushd $BUILD_DIR
    
    # get arm cross-compile toolchain. the toolchain is stored in a private S3 
    # bucket; we use travis-ci encryption to protect the keys to the bucket
    # ref: http://about.travis-ci.org/docs/user/encryption-keys/
    set +x # don't log keys!
    : ${AWS_ACCESS_KEY_ID:?"Need to set AWS_ACCESS_KEY_ID non-empty"}
    : ${AWS_SECRET_ACCESS_KEY:?"Need to set AWS_SECRET_ACCESS_KEY non-empty"}
    set -x 
    python -c 'import boto, os; boto.connect_s3(os.environ["AWS_ACCESS_KEY_ID"], os.environ["AWS_SECRET_ACCESS_KEY"]).get_bucket("exploitable").get_key("arm-toolchain-slim.tar.bz2").get_contents_to_filename("arm-toolchain.tar.bz2")'
    tar -xjf arm-toolchain.tar.bz2 # dir is arm-2013.11
    export PATH=$PATH:${BUILD_DIR}/arm-2013.11/bin
    cpath=$BUILD_DIR/arm-2013.11/bin/arm-none-linux-gnueabi-gcc
    if [ ! -f $cpath ]; then
      echo "Compiler not found at $cpath"
    else
      echo "Compiler found at $cpath"
      file $cpath
    fi

    # get ARM test VM (see http://wiki.qemu.org/Testing#QEMU_disk_images); 
    wget http://wiki.qemu.org/download/arm-test-0.2.tar.gz # &>> log-setup.txt # arm disk image
    tar -xzf arm-test-0.2.tar.gz # dir is arm-test
    
    # get python-equipped, ARM-compatible GDB (see https://wiki.mozilla.org/Mobile/Fennec/Android/GDB)
    wget http://people.mozilla.org/~nchen/jimdb/jimdb-arm-linux_x64.tar.bz2 
    tar -xjf jimdb-arm-linux_x64.tar.bz2 # directory is jimdb-arm
    popd
}

build() {
    # build ARM test cases
    pushd ${PROJECT_DIR}/exploitable/tests
    cpath=$BUILD_DIR/arm-2013.11/bin/arm-none-linux-gnueabi-gcc
    echo "Compiler path is $cpath"
    file $cpath
    CC=$BUILD_DIR/arm-2013.11/bin/arm-none-linux-gnueabi-gcc make -f Makefile.arm
    popd
    
    # patch VM initrd to run GDB server on startup
    mkdir ${BUILD_DIR}/initrd 
    pushd ${BUILD_DIR}/initrd 
    gunzip -c ${BUILD_DIR}/arm-test/arm_root.img | cpio -i -d -H newc
    cp ${PROJECT_DIR}/exploitable/tests/bin/* ${BUILD_DIR}/initrd/root/ # all test binaries
    cp ${BUILD_DIR}/arm-2013.11/bench/gdbserver ${BUILD_DIR}/initrd/root # gdbserver 
    chmod +x ${BUILD_DIR}/initrd/root/*
    echo "
    cd /root
    /root/gdbserver --multi 10.0.2.14:1234
    " >> ${BUILD_DIR}/initrd/etc/init.d/rcS
    rm ${BUILD_DIR}/arm-test/arm_root.img
    find . | cpio -o -H newc | gzip -9 > ${BUILD_DIR}/arm-test/arm_root.img
    popd
}

run_test() {
    # start VM wait for GDB server to start
    qemu-system-arm -kernel ${BUILD_DIR}/arm-test/zImage.integrator -initrd ${BUILD_DIR}/arm-test/arm_root.img -nographic -append "console=ttyAMA0" -net nic -net user,tftp=exploitable,host=10.0.2.33 -redir tcp:1234::1234 </dev/null &> ${BUILD_DIR}/log-qemu.txt &
    until grep "Listening on port" ${BUILD_DIR}/log-qemu.txt
    do
      echo "Waiting for GDB server to start..."
      cat ${BUILD_DIR}/log-qemu.txt
      sleep 1
    done
    echo "GDB server started"
    
    # run triage; we pass a bash script that will create a per-file remote-debug GDB script to the "step-script" argument for triage.py
    pushd ${PROJECT_DIR}

    cmd="#!/bin/bash
    
    template=\"set solib-absolute-prefix nonexistantpath
    set solib-search-path ${BUILD_DIR}/arm-2013.11/arm-none-linux-gnueabi/libc/lib
    file dirname/filename
    target extended-remote localhost:1234
    set remote exec-file /root/filename
    run
    source ${PROJECT_DIR}/exploitable/exploitable.py
    exploitable -p /tmp/triage.pkl\"
    d=\`dirname \$1\`
    f=\`basename \$1\`
    sub=\${template//filename/\$f}
    sub=\${sub//dirname/\$d}
    echo \"\$sub\" > ${BUILD_DIR}/gdb_init"

    echo "$cmd" > ${BUILD_DIR}/pre_run.sh
    chmod +x ${BUILD_DIR}/pre_run.sh
    python triage.py -o ${BUILD_DIR}/result.json -vs ${BUILD_DIR}/pre_run.sh -g "${BUILD_DIR}/jimdb-arm/bin/gdb --batch -x ${BUILD_DIR}/gdb_init --args " \$sub `find exploitable/tests/bin -type f` 
    rm ${BUILD_DIR}/pre_run.sh ${BUILD_DIR}/gdb_init
    popd
    
    # kill VM
    killall qemu-system-arm

    # check results
    python -c "import json, sys; from triage import *; sys.exit(sorted(filter(lambda x: x[1], json.load(file('${BUILD_DIR}/result.json')))) != sorted(filter(lambda x: x[1], json.load(file('${PROJECT_DIR}/test/arm-expected.json')))))"
}

clean() {
    # clean up 
    pushd ${PROJECT_DIR}/exploitable/tests && make -f Makefile.arm clean && popd
    rm -rf ${BUILD_DIR}
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
exit 
