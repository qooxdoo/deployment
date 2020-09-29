![deploy qooxdoo](https://github.com/qooxdoo/deployment/workflows/deploy%20qooxdoo/badge.svg)

# Qooxdoo releases & deployment

This repo contains experimental code to separate the release and deployment
workflow from the development workflow. The idea is that tests run in the
codebase repositories and ensure quality and integrity of the the code. When
they pass, they send a `repository_dispatch` event to this repo to trigger
deployment, which then runs its own workflow to test release and deployment
prerequisites. If these tests fail, deployment/release is prevented, but without
affecting development workflows. The failure can then be addressed in the
codebase repos.

The code in this repo is designed to be used on any *nux based
workstation - it will hopefully be possible to run them on Bash for
Windows 10, but that has not been tested. On Mac OS, you need to use or
[install](https://itnext.io/upgrading-bash-on-macos-7138bd1066ba) a newer Bash
shell (>=v4) than the one shipped with the OS; the most straighforward way is
to use Homebrew and do `brew install bash`, which will give you version 5.

To run compilation, just try: 

```
$ ./deployer.sh --verbose`
```

That command will checkout all of the supported repos (plus the compiler and framework 
which are always checked out), bootstrap the recursive dependencies between compiler 
and framework, and then proceed to compiler the other repos.

You can override some settings by creating a folder called "local" and adding
a file called "config.sh" in it.  

By default, all repos are checked out into a temporary working directory but you 
can override this in "local/config.sh" by providing alternative paths, eg:

```
REPO_DIRS[qooxdoo-compiler]=../QxCompiler
REPO_DIRS[qooxdoo]=../qooxdoo
```

This will not stop the deployer.sh script from patching the node_modules directory
to resolve the recursive bootstrap, but it does mean that you can use your existing
development tree as part of the deployment for testing

Currently, API viewer is the only supported repo but as more are added the compilation
time will get very long; you can limit this by setting "LOCAL_ENABLE_REPOS" to a 
space separated list of repo names in "local/config.sh"

**NOTE** currently, the scripts in this repo simply resolve dependencies and bootstrap -
the release and testing functionality needs to be added

Discussion: https://github.com/qooxdoo/qooxdoo/issues/10005

## Resources

- https://blog.marcnuri.com/triggering-github-actions-across-different-repositories/
- https://github.com/marketplace/actions/repository-dispatch
- https://semantic-release.gitbook.io/semantic-release/
- https://www.conventionalcommits.org/en/v1.0.0/
- https://github.com/conventional-changelog/commitlint#what-is-commitlint
- https://github.com/semantic-release/semantic-release/blob/master/docs/recipes/pre-releases.md#working-on-a-future-release
- https://github.com/marketplace/actions/action-for-semantic-release
