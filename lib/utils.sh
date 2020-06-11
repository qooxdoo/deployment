
#
# This script is intended to be included in other scripts, not executed directly
#



##
# Displays a message and exits
#
# @param msg {String} the message to display
# @param code {Integer?} the error code, defaults to 1
#
function errorExit {
    local msg=$1
    local code=$2
    echo $msg >&2
    [[ $code == "" ]] && code=1
    exit $code
}

##
# Displays a message on the console if the --verbose argument is used 
#
# @param msg {String} the message to display
#
function verbose {
    local msg=$1
    [[ $VERBOSE == 1 ]] && echo $msg
}

##
# Tests whether a string starts with another string
#
# @param wholeString {String}
# @param subString {String}
# @return true or false
#
startsWith() { 
    local wholeString="$1"
    local subString="$2"
    case "$wholeString" in 
        "$subString"*) true;; 
        *) false;; 
    esac
}

##
# Tests whether the directory is a working directory or not
#
# @param dir {String} the directory
# @return 0 (ie true) if it is inside the WORKING_ABS_DIR directory
#
function isWorking {
    local dir=$1
    dir=$(makeAbsolute $dir)
    local is=0
    startsWith "$dir" "$WORKING_ABS_DIR"
    is=$?

    return $is
}

##
# Makes a path absolute and resolves symlinks
#
# @param file {String} filename to resolve
# @output {String} the absolute, dereferenced path
#
function makeAbsolute {
    local file=$1
    [[ ! -d $file ]] && errorExit "Cannot find directory $file"
    file="$(cd $file; pwd -P)"
    echo $file
}

##
# Tests whether a whole word is in a string
#
# @param word {String}
# @param wholeString {String}
# @return true if found
#
function wordInString {
    local word="$1"
    local wholeString="$2"
    echo $wholeString | grep -w "$word" > /dev/null
    local code=$?
    return $code
}

##
# Changes directory with pushd, but will exit with an error code if the 
# directory does not exist.  Suppresses all console output
#
# @param dir {String} the directory
#
function pushDirSafe {
    local dir=$1
    if [[ ! -d $dir ]] ; then
        errorExit "Cannot find directory $dir to change to!"
    fi
    pushd $dir > /dev/null
}

##
# Pops directory with popd, suppresses all console output
#
function popDir {
    popd $dir > /dev/null
}

##
# Asks a question and expects a yes or no input (automatically answers yes if "-y" was used)
#
# @param question {String}
# @return true for yes, or false for no
function askYesNo {
    local question="$1"
    local answer
    echo -n "$question [Y/N] ? "
    read answer
    if [[ $answer == y || $answer == Y ]] ; then
        return 0
    else
        return 1
    fi
}

