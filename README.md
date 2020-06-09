# Qooxdoo releases & deplyoment

This repo contains experimental code to separate the release and deployment
workflow from the development workflow. The idea is that tests run in the
codebase repositories and ensure quality and integrity of the the code. When
they pass, they send a `repository_dispatch` event to this repo to trigger
deployment, which then runs its own workflow to test release and deployment
prerequisites. If these tests fail, deployment/release is prevented, but without
affecting development workflows. The failure can then be addressed in the
codebase repos.  

> :warning: Not working yet, ATM just a collection of links & code fragments

Discussion: https://github.com/qooxdoo/qooxdoo/issues/10005

## Resources

- https://blog.marcnuri.com/triggering-github-actions-across-different-repositories/
- https://github.com/marketplace/actions/repository-dispatch
- https://semantic-release.gitbook.io/semantic-release/
- https://www.conventionalcommits.org/en/v1.0.0/
- https://github.com/conventional-changelog/commitlint#what-is-commitlint
- https://github.com/semantic-release/semantic-release/blob/master/docs/recipes/pre-releases.md#working-on-a-future-release
- https://github.com/marketplace/actions/action-for-semantic-release
