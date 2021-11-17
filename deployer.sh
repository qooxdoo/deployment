#!/usr/bin/env bash
set -e
#set -x

# Preset default command line args
ANSWER_YES=0
BUILD_TARGET=1
CLEAN=0
RUN_TESTS=1
VERBOSE=0
QUIET=0
USAGE=0
PUBLISH=0
NPM_COMMAND="publish --access public"

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
        "--publish")
            PUBLISH=1
            ;;

        "--no-publish")
            PUBLISH=0
            ;;
            
        "--npm-pack")
            NPM_COMMAND="pack"
            ;;
			
        "--enable-repos")
            LOCAL_ENABLE_REPOS="$2"
            shift
            ;;

        "--no-run-tests")
            RUN_TESTS=0
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
            
        "--quiet"|"-q")
            QUIET=1
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
    echo "  --publish                   - do the publishing"
    echo "  --npm-pack                  - use npm pack instead of npm publish"
    echo "  --enable-repos [list]       - exhaustive list of repos to enable, space separated in quotes"
    echo "  --source                    - compile source targets instead of build"
    echo "  --no-run-tests              - do not run unit tests in repos - compile only (default is to run tests)"
    echo "  --clean                     - clean the working directory"
    echo "  --yes, -y                   - answer yes to all prompts"
    echo "  --verbose, -v               - verbose output"
    echo "  --help, -h                  - show usage help"
    exit 0
fi

if [[ $VERBOSE != 0 ]] ; then
    echo -e "\e[33mused flags"
    echo "ANSWER_YES=$ANSWER_YES"
    echo "BUILD_TARGET=$BUILD_TARGET"
    echo "CLEAN=$CLEAN"
    echo "RUN_TESTS=$RUN_TESTS"
    echo "VERBOSE=$VERBOSE"
    echo "QUIET=$QUIET"
    echo "USAGE=$USAGE"
    echo "NPM_COMMAND=$NPM_COMMAND"
    echo "PUBLISH=$PUBLISH"

    echo node version: $(node --version)
    echo npm version:  $(npm --version)
    echo -e "\e[39m"
fi



# Clean start
if [[ $CLEAN != 0 ]] ; then
    if askYesNo "Completely delete $WORKING_DIR" ; then
        info "Deleting $WORKING_DIR"
        rm -rf $WORKING_DIR
    else
        errorExit "Cannot delete $WORKING_DIR, so aborting"
    fi
    QX_COMPILE_ARGS="$QX_COMPILE_ARGS --clean"
fi

if [[ $BUILD_TARGET != 0 ]] ; then
    QX_COMPILE_ARGS="$QX_COMPILE_ARGS --target=build"
fi

if [[ $VERBOSE != 0 ]] ; then
    QX_COMPILE_ARGS="$QX_COMPILE_ARGS --verbose"
elif [[ $QUIET != 0 ]] ; then
    QX_COMPILE_ARGS="$QX_COMPILE_ARGS --quiet"
fi


# Initialise the working directory
mkdir -p $WORKING_DIR
WORKING_ABS_DIR=$(makeAbsolute $WORKING_DIR)
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
REPO_BRANCHES[qooxdoo]="latest"


# Handy list of enabled repos
ENABLED_REPOS=""
for repo in "${!REPO_ENABLED[@]}" ; do
    ENABLED_REPOS="$ENABLED_REPOS $repo"
done

PACKAGE_DATE=$(date +%Y%m%d-%H%M)
FRAMEWORK_VERSION=
COMPILER_VERSION=

#
# Framework bootstrap
#
function bootstrapFramework {
    info "Bootstrapping the framework..."
    checkoutRepo "qooxdoo"
    checkRepoNodeModules "qooxdoo"
}
bootstrapFramework


#
# Compiler bootstrap
#
function bootstrapCompiler {
    info "Bootstrapping the compiler"
    checkoutRepo "qooxdoo-compiler"
    checkRepoNodeModules "qooxdoo-compiler"

    local frameworkRepoDir=${REPO_ABS_DIRS["qooxdoo"]}
    local compilerRepoDir=${REPO_ABS_DIRS["qooxdoo-compiler"]}

    if isWorking $compilerRepoDir ; then
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
    fi

    verbose "Building the compiler"
    pushDirSafe $compilerRepoDir
    local VERSION=$(jq -M --raw-output '.info.version' Manifest.json)
    if [[ "$VERSION" =~ (alpha|beta) ]]; then
      VERSION="$VERSION-$PACKAGE_DATE"
    fi
    [[ ! -f ${REPO_ABS_DIRS[qooxdoo-compiler]}/compiled/node/build/compiler/index.js ]] && ./bootstrap-compiler $VERSION
    popDir
    COMPILER_VERSION=$VERSION
    
    # Setup the compiler / working bin directory
    [[ ! -d $WORKING_ABS_DIR/bin ]] && mkdir -p $WORKING_ABS_DIR/bin
    rm -f $WORKING_ABS_DIR/bin/qx
    ln -s ${REPO_ABS_DIRS[qooxdoo-compiler]}/bin/build/qx $WORKING_ABS_DIR/bin
}
bootstrapCompiler

# Checkout any repos which we need
for repo in $ENABLED_REPOS ; do
    [[ $repo == "qooxdoo" || $repo == "qooxdoo-compiler" ]] && continue

    info "Checking out $repo..."
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


# Make sure that we're using the framework repo for everything that we do 
$WORKING_ABS_DIR/bin/qx config set qx.library "${REPO_ABS_DIRS[qooxdoo]}/framework"


# Compile and test repos
qxCmd=compile
if [[ $RUN_TESTS != 0 ]] ; then
    qxCmd=test
fi
for repo in $ENABLED_REPOS ; do
    [[ $repo == "qooxdoo" ]] && continue

    info "compile and test $repo"
    repoDir=${REPO_DIRS[$repo]}
    pushDirSafe $repoDir
    $WORKING_ABS_DIR/bin/qx $qxCmd $QX_COMPILE_ARGS
    popDir
done

info "Bootstrap is resolved and repos are compiled"

# fill .npmrc with access token
echo "//registry.npmjs.org/:_authToken=${NPM_TOKEN:-}" > ~/.npmrc


[[ ! -d $WORKING_ABS_DIR/deploy ]] && mkdir -p $WORKING_ABS_DIR/deploy
rm -fR $WORKING_ABS_DIR/deploy/*

function publishFramework {
    info "publish qooxdoo framework"

    pushDirSafe ${REPO_ABS_DIRS["qooxdoo"]}
    local VERSION=$(jq -M --raw-output '.info.version' Manifest.json)
    if [[ "$VERSION" =~ (alpha|beta) ]]; then
      VERSION="$VERSION-$PACKAGE_DATE"
    fi
    verbose "new version $VERSION"

    verbose "publish @qooxdoo/server"
    mkdir -p $WORKING_ABS_DIR/deploy/server
    $WORKING_ABS_DIR/bin/qx deploy --config-file=compile-server.json --out=$WORKING_ABS_DIR/deploy/server/lib --clean $QX_COMPILE_ARGS
    cp *.md          $WORKING_ABS_DIR/deploy/server
    cp LICENSE       $WORKING_ABS_DIR/deploy/server
    jq --arg version $VERSION '.info.version=$version' Manifest.json > $WORKING_ABS_DIR/deploy/server/Manifest.json
    popDir
    pushDirSafe $WORKING_ABS_DIR/deploy/server
    cp $DEPLOY_DIR/packages/server/package.json .
    npm version $VERSION
    if [[ $PUBLISH = 1 ]] ; then
      npm $NPM_COMMAND
    fi
    popDir

    verbose "publish @qooxdoo/framework"
    pushDirSafe ${REPO_ABS_DIRS["qooxdoo"]}
    mkdir -p $WORKING_ABS_DIR/deploy/framework
    cp *.md          $WORKING_ABS_DIR/deploy/framework
    cp LICENSE       $WORKING_ABS_DIR/deploy/framework
    jq --arg version $VERSION '.info.version=$version' framework/Manifest.json > $WORKING_ABS_DIR/deploy/framework/Manifest.json
    mkdir -p $WORKING_ABS_DIR/deploy/framework/source
    cp -R framework/source/* $WORKING_ABS_DIR/deploy/framework/source
    mkdir -p $WORKING_ABS_DIR/deploy/framework/tool/data/cldr
    cp -R tool/data/cldr/* $WORKING_ABS_DIR/deploy/framework/tool/data/cldr
    popDir
    pushDirSafe $WORKING_ABS_DIR/deploy/framework
    cp $DEPLOY_DIR/packages/framework/package.json .
    npm version $VERSION
    FRAMEWORK_VERSION=$VERSION
    if [[ $PUBLISH = 1 ]] ; then
      npm $NPM_COMMAND 
    fi
    popDir

}
publishFramework
# wait a minute for npm publish to work
if [[ $PUBLISH = 1 ]] ; then
   sleep 600
fi

function publishCompiler {
    info "publish qooxdoo compiler"
    pushDirSafe ${REPO_ABS_DIRS["qooxdoo-compiler"]}	
    verbose "new version $COMPILER_VERSION"
    npm --no-git-tag-version --allow-same-version version $COMPILER_VERSION   # adapt version for compiler info
    mkdir -p $WORKING_ABS_DIR/deploy/compiler
    $WORKING_ABS_DIR/bin/qx deploy --out=$WORKING_ABS_DIR/deploy/compiler/lib --app-name=compiler --clean $QX_COMPILE_ARGS
    cp *.md                 $WORKING_ABS_DIR/deploy/compiler
    cp LICENSE              $WORKING_ABS_DIR/deploy/compiler
    mkdir -p $WORKING_ABS_DIR/deploy/compiler/bin
    cp -R bin/*      $WORKING_ABS_DIR/deploy/compiler/bin
    jq --arg version $COMPILER_VERSION '.info.version=$version' Manifest.json > $WORKING_ABS_DIR/deploy/compiler/Manifest.json
    jq -M 'del(.devDependencies) | del(.scripts)' package.json \
    > $WORKING_ABS_DIR/deploy/compiler/package.json
    jq -M 'del(.dependencies["@qooxdoo/compiler"]) | del(.dependencies["tape"]) | del(.dependencies["source-map-support"])' npm-shrinkwrap.json \
    > $WORKING_ABS_DIR/deploy/compiler/npm-shrinkwrap.json
    popDir
    pushDirSafe $WORKING_ABS_DIR/deploy/compiler
    if [[ $PUBLISH = 1 ]] ; then
      npm install @qooxdoo/framework@$FRAMEWORK_VERSION
      npm $NPM_COMMAND
    fi
    popDir
}
publishCompiler

