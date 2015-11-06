# COPR-STATUS

----

[![License](https://img.shields.io/badge/license-AGPLv3-green.svg)]("https://github.com/spb-tools/copr-status/COPYING")
[![Gitter](https://badges.gitter.im/Join%20Chat.svg)](https://gitter.im/spb-tools/copr-status?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge)

----

# About

----

> This app was built to support the development of Portal do Software Público
Brasileiro. It shows versions for published packages in EPEL7 Fedora Copr
repositories. Note that this app consists of a single PSGI script, a template
file and Bootstrap.

----
# Development

> In order to use this app you will need perl 5 and the following perl modules
installed:

* Plack
* LWP::UserAgent
* JSON
* Text::Template

> Run tests:

```
prove -Ilib t
```
----
# How to use

> If you want to use this app, you can simply using plackup as the command
below:

```
plackup [--port PORT_NUMBER] -Ilib
```

> For example, try:

```
plackup -Ilib
```
