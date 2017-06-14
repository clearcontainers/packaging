# cc-runtime

This directory contains the sources to create rpm spec files and Debian* source
control files to create the ``pause`` binary from
http://github.com/containers/virtcontainers.

To generate the Fedora* and Ubuntu* packages for this component enter:

``./update_pause.sh [VERSION]``

The ``VERSION`` parameter is optional. The parameter can be a tag, a branch,
or a GIT hash.

If the ``VERSION`` parameter is not specified, it will be taken from the
top-level ``versions.txt`` file.

This script will update the sources to create ``virtcontainers-pause`` files:

  * virtcontainers-pause.dsc
  * virtcontainers-pause.spec
  * debian.*
