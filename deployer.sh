#!/usr/bin/env bash
set -e

# Preset default command line args
QX_CMD="npx qx"
ANSWER_YES=0
PULL_ALL=1
RESET_NPM=0
BUILD_TARGET=1
CLEAN=0
RUN_TESTS=1
VERBOSE=0
USAGE=0


# Directory that this script is in
DEPLOY_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"


# Declare globals
declare -A REPO_ABS_DIRS
declare -A REPO_IS_WORKING
QX_COMPILE_ARGS=

# Load utility methods
. ./lib/utils.sh
. ./lib/repo-handling.sh

# Load configs
. ./lib/globals.sh
[[ -f ./local/config.sh ]] && source ./local/config.sh


#
# Process command line
#
while [[ $1 != "" ]] ; do
    case "$1" in
        "--enable-repos")
            LOCAL_ENABLE_REPOS="$2"
            shift
            ;;

        "--qx-cmd"|"-q")
            QX_CMD="$2"
            shift
            ;;

        "--pull-all"|"-a")
            PULL_ALL=1
            ;;

        "--reset-npm"|"-r")
            RESET_NPM=1
            ;;

        "--run-tests")
            RUN_TESTS=1
            ;;

        "--source")
            BUILD_TARGET=0
            ;;

        "--clean")
            CLEAN=1
            ;;

        "--verbose"|"-v")
            VERBOSE=1
            ;;

        "--yes"|"-y")
            ANSWER_YES=1
            ;;

        "--help"|"-h")
            USAGE=1
            ;;
    esac
    shift
done

if [[ $USAGE != 0 ]] ; then
    echo "Usage: $0 [options]"
    echo "where options are:"
    echo "  --qx-cmd, q command         - the qx command used for bootstrapping, defaults to 'npx qx'"
    echo "  --enable-repos [list]       - exhaustive list of repos to enable, space separated in quotes"
    echo "  --pull-all, -p              - force a pull from all repos"
    echo "  --reset-npm, -r             - erase and reinstall node_modules in all repos"
    echo "  --source                    - compile source targets instead of build"
    echo "  --run-tests                 - run unit tests in repos"
    echo "  --clean                     - clean the working directory"
    echo "  --yes, -y                   - answer yes to all prompts"
    echo "  --verbose, -v               - verbose output"
    echo "  --help, -h                  - show usage help"
    exit 0
fi


# Clean start
if [[ $CLEAN != 0 ]] ; then
    if askYesNo "Completely delete $WORKING_DIR" ; then
        verbose "Deleting $WORKING_DIR"
        rm -rf $WORKING_DIR
    else
        errorExit "Cannot delete $WORKING_DIR, so aborting"
    fi
    QX_COMPILE_ARGS="$QX_COMPILE_ARGS --clean"
fi


# Initialise the working directory
mkdir -p $WORKING_DIR
WORKING_ABS_DIR=$(makeAbsolute $WORKING_DIR)
export PATH=$WORKING_ABS_DIR/bin:$PATH
verbose "WORKING_ABS_DIR=$WORKING_ABS_DIR"


# Handy list of repo IDs
REPOS="${!REPO_DIRS[@]}"


# Choose which repos to enable
if [[ $LOCAL_ENABLE_REPOS != "" ]] ; then
    for repo in $REPOS ; do
        REPO_ENABLED[$repo]=0
    done
    for repo in $LOCAL_ENABLE_REPOS ; do
        REPO_ENABLED[$repo]=1
    done
fi


# The framework and the compiler are always enabled
REPO_ENABLED[qooxdoo]=1
REPO_ENABLED[qooxdoo-compiler]=1


# Handy list of enabled repos
ENABLED_REPOS=""
for repo in "${!REPO_ENABLED[@]}" ; do
    ENABLED_REPOS="$ENABLED_REPOS $repo"
done




#
# Framework bootstrap
#
function bootstrapFramework {
    verbose "Bootstrapping the framework..."
    checkoutRepo "qooxdoo"
#    checkRepoNodeModules "qooxdoo"
}
bootstrapFramework


#
# Compiler bootstrap
#
function bootstrapCompiler {
    verbose "Bootstrapping the compiler..."
    checkoutRepo "qooxdoo-compiler"
    checkRepoNodeModules "qooxdoo-compiler"

    if [[ $BUILD_TARGET != 0 ]] ; then
        QX_COMPILE_ARGS="$QX_COMPILE_ARGS --target=build"
    fi
	
    if [[ $VERBOSE != 0 ]] ; then
        QX_COMPILE_ARGS="$QX_COMPILE_ARGS --verbose"
    fi

    # Setup the compiler / working bin directory
    if [[ ! -f $WORKING_ABS_DIR/bin/qx ]] ; then
        mkdir -p $WORKING_ABS_DIR/bin
        ln -s ${REPO_ABS_DIRS[qooxdoo-compiler]}/bin/qx $WORKING_ABS_DIR/bin
    fi

    local frameworkRepoDir=${REPO_ABS_DIRS["qooxdoo"]}
    local compilerRepoDir=${REPO_ABS_DIRS["qooxdoo-compiler"]}

    # If the compiler is not linked to our framework, then we need to switch it over
    if [[ ! -L $compilerRepoDir/node_modules/@qooxdoo/framework/ ]] ; then
        verbose "Installing locally framework source into the compiler..."
        rm -rf $compilerRepoDir/node_modules/@qooxdoo/framework
        mkdir -p $compilerRepoDir/node_modules/@qooxdoo/framework
        ln -s $frameworkRepoDir/framework/source $compilerRepoDir/node_modules/@qooxdoo/framework/source
        # we need a hard link here - node do not follow the sym links and resolves the wrong directory
        ln $frameworkRepoDir/Manifest.json $compilerRepoDir/node_modules/@qooxdoo/framework/Manifest.json
        ln $frameworkRepoDir/package.json  $compilerRepoDir/node_modules/@qooxdoo/framework/package.json
    fi

    verbose "build the compiler from repo"
    pushDirSafe $compilerRepoDir
    $QX_CMD deploy $QX_COMPILE_ARGS --app-name=compiler
    popDir
}
bootstrapCompiler



# Checkout any repos which we need
for repo in $ENABLED_REPOS ; do
    [[ $repo == "qooxdoo" || $repo == "qooxdoo-compiler" ]] && continue

    verbose "Checking out $repo..."
    checkoutRepo $repo
    checkRepoNodeModules $repo
done


# Initialise / reset node_modules to make them link to local copies
for repo in $ENABLED_REPOS ; do
    repoDir=${REPO_DIRS[$repo]}
    pushDirSafe $repoDir

    for linkedRepo in $ENABLED_REPOS ; do
        [[ $linkedRepo == $repo ]] && continue

        linkedRepoDir=${REPO_DIRS[$linkedRepo]}
        linkedNpmName=${REPO_NPM_NAMES[$linkedRepo]}

        if [[ -d node_modules/@qooxdoo/$linkedNpmName ]] ; then
            rm -rf node_modules/@qooxdoo/$linkedNpmName
            ln -s $linkedRepoDir node_modules/@qooxdoo/$linkedRepo
        fi
    done
    popDir
done


# Compile repos
for repo in $ENABLED_REPOS ; do
    [[ $repo == "qooxdoo" || $repo == "qooxdoo-compiler" ]] && continue
    repoDir=${REPO_DIRS[$repo]}
    pushDirSafe $repoDir
    $WORKING_ABS_DIR/bin/qx compile $QX_COMPILE_ARGS
    popDir
done


echo "Bootstrap is resolved and repos are compiled"
