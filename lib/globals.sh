
#
# This file contains global settings used by the deployer.sh script.  If you want to override them
# for your own personal setup, create or edit a file in the local/ folder called config.sh and
# that will be executed at the end of this one, so that it can override settings.
#
# Generally speaking, if there's something you want to change, look for variables which start LOCAL_
#   because these are intended to be changed by local/config.sh
#

#
# Temporary directory for deployer.sh
#
WORKING_DIR=./working


#
# LOCAL_ENABLE_REPOS
#
# If set, this will limit the list of repos which are enabled to those which are listed in here;
#   this is a space-separated list
#
LOCAL_ENABLE_REPOS=

#
# REPO_DIRS is an associative array saying directories to find the repo
#
declare -A REPO_DIRS

#
# REPO_URLS is an associative array of GitHub repo urls
#
declare -A REPO_URLS

#
# REPO_NPM_NAMES is an associative array of npmjs.com repo names, defaults to "@qooxdoo/REPO-NAME"
#
declare -A REPO_NPM_NAMES

#
# REPO_ENABLED is an associative array that says whether each repo is enabled
#
declare -A REPO_ENABLED


# initialise associative arrays
for repo in qooxdoo-compiler qooxdoo qxl.apiviewer ; do
    REPO_DIRS[$repo]="$WORKING_DIR/repos/$repo"
    REPO_URLS[$repo]="https://github.com/qooxdoo/$repo"
    if [[ $repo == "qooxdoo" ]] ; then
        REPO_NPM_NAMES[$repo]="@qooxdoo/framework"
    elif [[ $repo == "qooxdoo-compiler" ]] ; then
        REPO_NPM_NAMES[$repo]="@qooxdoo/compiler"
    else
        REPO_NPM_NAMES[$repo]="@qooxdoo/$repo"
    fi
    REPO_ENABLED[$repo]=1
done

