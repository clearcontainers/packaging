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


Repositories
============

* CentOS

  * 7.x http://download.opensuse.org/repositories/home:/clearcontainers:/clear-containers-3/CentOS_7/

* Fedora

  * 24 http://download.opensuse.org/repositories/home:/clearcontainers:/clear-containers-3/Fedora_24/
  * 25 http://download.opensuse.org/repositories/home:/clearcontainers:/clear-containers-3/Fedora_25/
  * 26 http://download.opensuse.org/repositories/home:/clearcontainers:/clear-containers-3/Fedora_26/

* OpenSUSE

  * Tumbleweed http://download.opensuse.org/repositories/home:/clearcontainers:/clear-containers-3/openSUSE_Tumbleweed/

* RHEL

  * 7.x http://download.opensuse.org/repositories/home:/clearcontainers:/clear-containers-3/RHEL_7/

* Ubuntu

  * 16.04 http://download.opensuse.org/repositories/home:/clearcontainers:/clear-containers-3/xUbuntu_16.04/
  * 16.10 http://download.opensuse.org/repositories/home:/clearcontainers:/clear-containers-3/xUbuntu_16.10/
  * 17.04 http://download.opensuse.org/repositories/home:/clearcontainers:/clear-containers-3/xUbuntu_17.04/

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

Local Building
==============

Any user can build their own Clear Containers packages using the source files provided in this
repository, either by using the OBS platform or their own machines using the ``osc`` (Open Build Service command line tool).

In this repository, a Dockerfile is provided to build a container that has all the tools needed to perform local builds.
Use the following instructions to build Clear Containers packages within the container:

NOTES:

When local building, a prompt will pop up asking for OBS credentials for the first time, the osc tool will contact
the OBS API for retrieving the current OBS revision of a given package and the buildroot packages. If you don't
have an account, you can create one from the main OBS site: https://build.opensuse.org/

.. code-block:: shell

   # cd into this repository
   $ cd <this repo location>

   # build the container image
   # cc-osc name is used for the tag, it can be anything.
   $ sudo docker build -t cc-osc .

   # If you are behind a proxy, use instead the following paramenters to build the container.
   $ sudo docker build --build-arg=http_proxy=http://<host>:<port> --build-arg=https_proxy=http://<host>:<port> -t cc-osc .

   # Run the container and bind this repository.
   # In order to make the packages visible from the host, we need to bind a host directory
   # to the directory within the container where the packages are stored (/var/packaging/results).
   # Change the results variable to change the default host directory.
   $ results=/var/packaging/results
   $ sudo mkdir -p "$results"
   $ sudo docker run -v $PWD:/root/packaging -v /var/packaging/results:$results -it cc-osc bash

   # Inside the container, cd to a project, runtime in this case
   $ cd /root/packaging/runtime

   # To see the options, arguments, etc
   $ ./update_runtime.sh --help

   # to build locally, run the setup script with the following parameters:
   $ ./update_runtime.sh --local-build --verbose

   # If something goes wrong, the build logs can be found in /var/packaging/build_logs within the container.
