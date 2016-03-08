# COPR-STATUS

----

[![License](https://img.shields.io/badge/license-AGPLv3-green.svg)]("https://github.com/spb-tools/copr-status/COPYING")
[![Gitter](https://badges.gitter.im/Join%20Chat.svg)](https://gitter.im/spb-tools/copr-status?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge)

----

# About

----

> This app was built to support the development of Portal do Software Público
Brasileiro. It shows versions for published packages in EPEL7 Fedora Copr
repositories. Note that this app consists of a package (CoprStatus), a
PSGI script, a script to update information on .spec files, a template file
and Bootstrap.

----
# Development

> In order to use this app you will need perl 5 and the following perl modules
installed:

* Plack
* LWP::UserAgent
* JSON
* YAML:XS
* Text::Template
* LWP::Protocol::https
* RPM::VersionCompare

> Run tests:

```
prove -Ilib t
```
----
# How to use

```
plackup [--port PORT_NUMBER] -Ilib
```

> For example, try:

```
plackup -Ilib
```

> There is a util/update_files.pl file that must be running
in order to update spec files.

----
# Configuration

> The file config.yaml sets all the needed parameters:

* User: Copr user, the owner of the repository to be watched
* UpdateRate: Rate in witch information on Git and Copr are updated
* GitDomain: Forge system used to host git repositories, like github or gitlab.
* GitSpecPath: Path to spec files in the git repository: use <branch> instead of the branch name and <package> instead of package names.
* Repositories: name of Copr repositories for User.
* Branches: name of git branches to be watched.

