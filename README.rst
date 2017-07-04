.. contents::
.. sectnum::

Intel® Clear Containers 3.0 OBS specification files
###################################################


The `Clear Containers`_ packages are available via `Open Build Service`_
to allow interested parties the opportunity to try out the technology.

When the `runtime`_ or any of its components are updated, we release a set
of packages, via `OBS`_

Visit our repository at:

- https://build.opensuse.org/project/show/home:clearcontainers:clear-containers-3

Included components
===================

* `runtime`_: Clear Containers 3.0 `OCI`_ compatible runtime.
* `proxy`_: Hypervisor based containers proxy
* `shim`_: Hypervisor based containers shim
* `clear-containers-image`_: Includes the mini-OS required to run Clear
  Containers.
* `clear-containers-selinux`_: Includes the SELinux policy module needed to
  run Clear Containers in environments with SELinux enabled.
* `kernel`_: Includes patches to build an optimized linux kernel required to run Clear
  Containers
* `qemu-lite`_: Includes an optimized version of the QEMU hypervisor.


.. _`Clear Containers`:  https://clearlinux.org/features/intel%C2%AE-clear-containers

.. _`OCI`:  https://www.opencontainers.org/

.. _`runtime`: https://github.com/clearcontainers/runtime

.. _`proxy`: https://github.com/clearcontainers/proxy

.. _`shim`: https://github.com/clearcontainers/shim

.. _`Open Build Service`: http://openbuildservice.org/

.. _`OBS`: http://openbuildservice.org/

.. _`qemu-lite`: https://github.com/01org/qemu-lite/tree/qemu-2.7-lite

.. _`kernel`: https://github.com/clearcontainers/packaging/tree/master/kernel

.. _`clear-containers-image`: https://download.clearlinux.org/current/

.. _`clear-containers-selinux`: https://github.com/clearcontainers/proxy/tree/master/selinux
