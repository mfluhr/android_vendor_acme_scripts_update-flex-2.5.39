#!/bin/bash -e
#
# Copyright (C) 2023 Mathieu Fluhr <mathieu.fluhr@gmail.com>
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

##
## This script updates the 'prebuilts/misc/linux-x86/flex/flex-2.5.39' 
## executable, recompiling it using the host platform build tools to avoid AOSP
## build failures on on a workstation running recent Linux distributions due to
## an assertion coming from the flex 'loadlocale.c' file like the following:
## ---
## flex-2.5.39: loadlocale.c:130: _nl_intern_locale_data: Assertion `cnt <
## (sizeof (_nl_value_type_LC_TIME) / sizeof (_nl_value_type_LC_TIME[0]))'
## failed.
## Aborted (core dumped)
## ---
##
## Usually, simply setting the LC_ALL (or LANG) environment variable to 'C' is
## sufficient to fix this, but in some corner cases, a new flex binary is
## required, for example when building Android 9 on a workstation running
## Ubuntu 22.04 LTS.
##

#
# Prebuilt flex-2.5.39 executable and source code archive location inside the
# AOSP source tree
#
PREBUILT_FLEX_EXEC_PATH="prebuilts/misc/linux-x86/flex/flex-2.5.39"
PREBUILT_FLEX_SRC_PATH="prebuilts/misc/linux-x86/flex/flex-2.5.39.tar.gz"

#
# The new 'flex' executable will be recompiled inside a temp folder, that will
# then be deleted upon script termination (Please see the 'replace_flex()'
# function for more details).
#
TEMP_FOLDER=$(mktemp -d)

function cleanup() {
    rm -rf "$TEMP_FOLDER"
}

trap cleanup EXIT

#
# Makes sure that the AOSP build environment has been properly setup using the
# 'build/envsetup.sh' script.
#
function check_env() {
    if [ -z "$ANDROID_BUILD_TOP" ]; then
        echo "ERROR: 'ANDROID_BUILD_TOP' is not set. Please make sure to initialize the"
        echo "build environment, calling 'source build/envsetup.sh' and 'lunch' before"
        echo "running this script."
        exit 1
    fi
}

#
# Makes sure that the AOSP source tree contains the flex source archive at the
# correct location. If this check fails, this usually indicates that the script
# is run inside a newer Android which does not need to be fixed.
#
function check_flex_src_path() {
    if [ ! -f "$PREBUILT_FLEX_SRC_PATH" ]; then
        echo "ERROR: '$PREBUILT_FLEX_SRC_PATH' not found"
        exit 1
    fi
}

#
# Replaces the 'prebuilts/misc/linux-x86/flex/flex-2.5.39' executable with a
# freshly compiled one, using the host platform build tools.
#
# The compilation is done following the instructions inside the
# 'prebuilts/misc/linux-x86/flex/PREBUILT' file.
#
function replace_flex() {
    pushd "$TEMP_FOLDER" > /dev/null
        tar zxf "$ANDROID_BUILD_TOP/$PREBUILT_FLEX_SRC_PATH"
        pushd "flex-2.5.39" > /dev/null
            set -x
            ./configure
            make CFLAGS="-static" LDFLAGS="-static"
            rm flex
            make CFLAGS="-static" LDFLAGS="-static" flex
            gcc -static -o "$ANDROID_BUILD_TOP/$PREBUILT_FLEX_EXEC_PATH" ccl.o dfa.o ecs.o scanflags.o gen.o main.o misc.o nfa.o parse.o scan.o skel.o sym.o tblcmp.o yylex.o options.o scanopt.o buf.o tables.o tables_shared.o filter.o regex.o  /usr/lib/x86_64-linux-gnu/libm.a
            set +x
        popd > /dev/null
    popd > /dev/null
}

check_env
check_flex_src_path
replace_flex

COLOR_SUCCESS=""
COLOR_RESET=""
NCOLORS=$(tput colors 2>/dev/null)
if [ -n "$NCOLORS" ] && [ $NCOLORS -ge 8 ]; then
    COLOR_SUCCESS=$'\E'"[0;32m"
    COLOR_RESET=$'\E'"[00m"
fi

echo ""
echo "${COLOR_SUCCESS}#### 'flex-2.5.39' binary replaced successfully ####${COLOR_RESET}"
echo ""

