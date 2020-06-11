
#
# This script is intended to be included in other scripts, not executed directly
#


##
# Checks out a repo
#
# @param repo {String} name of the repo
# 
function checkoutRepo {
    local repo=$1
    
    # Get values (and validate the _config.sh associative arrays)
    local repoDir=${REPO_DIRS[$repo]}
    [[ $repoDir == "" ]] && errorExit "Cannot find an entry in REPO_DIRS for $repo"
    local repoUrl=${REPO_URLS[$repo]}
    [[ $repoUrl == "" ]] && errorExit "Cannot find an entry in REPO_URLS for $repo"
    
    local created=false
    if [[ ! -d $repoDir ]] ; then
        echo "Cloning $repoUrl ..."
        created=true
        git clone $repoUrl $repoDir
    else
        if isWorking $repoDir ; then
            if [[ $PULL_ALL ]] ; then
                echo "Updating $repoUrl ..."
                pushDirSafe $repoDir
                git pull
                popDir
            fi
        fi
    fi
    
    repoDir=$(makeAbsolute $repoDir)
    REPO_ABS_DIRS[$repo]=$repoDir
    if isWorking $repoDir ; then
        REPO_IS_WORKING[$repo]=1
    else
        REPO_IS_WORKING[$repo]=0
        if [[ $created == true ]] ; then
            echo "Warning: Checked out $repo into a non-working directory $repoDir - its your responsibility to update it from now on"
        fi
    fi
}


##
# Checks a repos node_modules, optionally hard resetting them if neceessary
#
# @param repo {String} repo name
function checkRepoNodeModules {
    local repo=$1
    
    local repoDir=${REPO_DIRS[$repo]}
    
    if [[ -f $repoDir/package.json ]] ; then
        pushDirSafe $repoDir
        [[ $RESET_NPM == 1 ]] && rm -rf node_modules   
        [[ ! -d node_modules ]] && npm install
        popDir
    fi
}

