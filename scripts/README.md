# Packaging scripts

This directory contains useful packaging scripts.

## `configure-hypervisor.sh`

This script generates the official set of QEMU-based hypervisor build
configuration options. All repositories that need to build a hypervisor
from source **MUST** use this script to ensure the hypervisor is built
in a known way since using a different set of options can impact many
areas including performance, memory footprint and security.

Example usage:

```
  $ configure-hypervisor.sh qemu-lite
```

## `apport_hook.py`

This script is a basic hook which will call the cc-collect-data.sh script
when any of the components crashes (runtime, proxy, shim, qemu-lite).
The script output will then be added to the standard Ubuntu bug report
that will get created on launchpad.net.

## `get-image-changes.sh`

This script generates the list of changed packages that are used in Clear
Containers image.  The changes are collected from Clear Linux release notes:

```
https://download.clearlinux.org/releases/XXXX/clear/RELEASENOTES
```

The list of changes will be created from the current image version (defined
in `versions.txt`) to a version provided to the script.

Usage:

```
   $ ./get-image-changes.sh VERSION-TO-UPDATE > changes
   $ cat changes
```
