# cc-runtime

This directory contains the sources to create rpm spec files and Debian* source
control files to create the Intel® Clear Containers runtime: ``cc-runtime``.

To generate the Fedora* and Ubuntu* packages for this component enter:

``./update_runtime.sh [VERSION]``

The ``VERSION`` parameter is optional. The parameter can be a tag, a branch,
or a GIT hash.

If the ``VERSION`` parameter is not specified, it will be taken from the
top-level ``versions.txt`` file.

This script updates the sources to create the following ``cc-runtime`` files:

  * cc-runtime.dsc
  * cc-runtime.spec
  * debian.*