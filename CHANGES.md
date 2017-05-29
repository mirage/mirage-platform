## 3.0.0 (2017-01-24)
* [xen-ocaml] Add support for OCaml 4.04.0 (#173, by @yomimono)
* don't embed Str into the ocaml runtime (#175, by @hannesm)
* sleep in nanoseconds, not seconds (#168, by @hannesm)
* avoid memsetting NULL (#179, by @rixed)
* use mirage-clock-freestanding instead of mirage-clock-xen (#177, by @hannesm)
* use logs for errors (#171, by @hannesm)
* [xen-ocaml] for compiler version 4.04, set OCAML_OS_TYPE to "xen" (#178, by @yomimono)

## 2.6.0 (2016-05-05):
* [xen-ocaml] Add support for OCaml 4.03.0
* Add `strtod` and `strtol` implementations.
* Add stubbed out `isatty` function stub.

## 2.5.0 (2016-05-01):
* Remove use of deprecated `Lwt_unix.run`
* Support cstruct.2.0.0 (#163)
* Fix typos in license field.

## 2.4.1 (2016-03-22):
* Don't raise in an at_exit handler on Windows

## 2.4.0 (2016-03-18):
* mirage-unix now builds on win32
* Add appveyor support
* Add LICENSE file
* Allow packages to be built without the `opam` command0line tool
* Add OS.Lifecycle module. Allows unikernels to handle shutdown requests.
* Remove unmaintained ns3 module.
* Remove unused machine/ code

## 2.3.4 (2015-08-17):
* [xen-ocaml] Support OCaml 4.02.3 (#137, by @talex5)
* [xen-posix] Add -Wall to `xen-ocaml-build` and fix C warnings (#141, by @lnmx)

## 2.3.3 (2015-07-21):
* [xen-posix] Enable more compiler warnings (#134, by @talex5)
* [xen] Implement times and sysconf (#131, #134, by @talex5)

## 2.3.2 (2015-05-21):
* [xen] Synchronize Cstruct C stubs with version 1.6.0.

## 2.3.1 (2015-04-19):
* Fix uninstall of `mirage-xen-ocaml` (#126, patch from @hannesm)

## 2.3.0 (2015-03-17):
* Split `mirage-xen` into three opam packages: `mirage-xen-posix` (includes and
  mini-libc), `mirage-xen-ocaml` (OCaml runtime) and `mirage-xen` (bindings and
  OCaml OS libraries) (#125, patch from @hannesm)

## 2.2.3 (2015-03-16):
* Add opam files for `mirage-xen` and `mirage-unix` OPAM packages
* Remove page_stubs.c, now provided by io-page (#122, patch from @hannesm)

## 2.2.2 (2015-03-04):
* Add generic hooks to mainloop to support background tasks. (#120)
* [xen] Report trace events for GC again; this was disabled temporarily
  in the 2.2.0 release. (#119)

## 2.2.1 (2015-01-26):
* Fix Xen compilation with `gcc 4.8+` by disabling the stack protector
  and `-fno-tree-loop-distribute-patterns` (not compatible with MiniOS).
  These missing flags were a regression from 2.1.3, which did include them.

## 2.2.0 (2015-01-23):

This releases adds support for OCaml 4.02+ compilation, and changes the Xen
backend build for Mirage significantly by:

* removing the OCaml compiler runtime from the mirage-platform, which makes
  it simpler to work across multiple revisions of the compiler.  It now uses
  the `ocaml-src` OPAM package to grab the current switch's version of the
  OCaml runtime.
* split the Xen runtime build into discrete `pkg-config` libraries:
  * `mirage-xen-posix.pc` : in the `xen-posix/` directory, is the nano-posix
     layer built with no knowledge of OCaml
  * `mirage-xen-minios.pc`: defines the `__INSIDE_MINIOS__` macro to expose
     internal state via the MiniOS headers (for use only by libraries that
     know exactly what they are doing with the MiniOS)
  * `mirage-xen-ocaml.pc`: in `xen-ocaml/core/`, this builds the OCaml asmrun,
     Bigarray and Str bindings using the `mirage-xen-posix` layer.
  * `mirage-xen-ocaml-bindings.pc`: in `xen-ocaml/bindings/`, these are bindings
     required by the OCaml libraries to MiniOS.  Some of the bindings use MiniOS
     external state and hence use `mirage-xen-minios`, whereas others
    (`cstruct_stubs` and `barrier_stubs` are just OCaml bindings and so just
    use `mirage-xen-posix`).
  * `mirage-xen.pc`: depends on all the above to provide the same external
    interface as the current `mirage-platform`.

The OCaml code is now built using OASIS, since the C code is built entirely
separately and could be moved out into a separate OPAM package entirely.

## 2.1.3 (2015-01-23):
* [xen] Fix error handling in `OS.Main.run` to enable a top-level
  exception to signal to the Xen toolstack that it crashed (versus a
  clean exit). This in turn lets `on_crash="preserve"` behaviour work
  better in Xen VM description files.
* Remove `mirage-xen.pc` file on uninstall.

## 2.1.2 (2014-12-20):

[xen] Updated headers and build for Mini-OS 0.5.  This involves:

* Require libminios >= 0.5
* Remove old includes directory when installing
* Compile with `-fno-builtin` (avoids warnings about standard functions)
* Removed `complex.h` (now provided by Openlibm)
* Include `cdefs.h` from `types.h` (needed for `__BEGIN_DECLS`)
* Removed open from `unistd.h` (comes from `fcntl.h`)
* Removed `assert.h` and `__assert_fail` (provided by Mini-OS)
* Removed `string.h` (provided by Mini-OS)
* Removed `cdefs.h` (provided by Mini-OS)
* Added missing `console.h` includes (for `printk`)

## 2.1.1 (2014-12-17):
* Remove checksum stubs from Unix and Xen, as they are provided by `tcpip` now.
* [xen] Define UINTx_MAX and SIZE_MAX in stdint.h

## 2.1.0 (2014-12-07):
* [xen] Report trace events for GC, block_domain, XenStore and event channels.
  This introduces a new dependency on the `mirage-profile` package.
* [xen] Install a `pkg-config` file to allow other projects to compile C stubs
  against `mirage-xen`.
* [xen] Remove duplication of OCaml header files inside the `include` tree.

## 2.0.1 (2014-12-05):
* [xen] Assert that pages passed to the grant share API are page-aligned.
  This always happens if they are created via `Io_page.create`, and
  probably not true if made by `Cstruct.create`.
* [xen] Use monotonic time for timing events, not wall-clock time.
* [xen] Provide functions that C code often uses for asserts (`abort`,
  `printf`, etc).

## 2.0.0 (2014-11-04):
* Remove dietlibc, libm and most of the include files, replacing them with
  external dependencies on Mini-OS and openlibm.
* Introduce Xen/ARM support that works with both Xen 4.4 and the 4.5dev
  hypervisor ABI.  Testing on Cubieboard2 and Cubietruck devices.
* [xen] Move the Xen main Lwt loop into OCaml code to simplify it (#99).
* Build fixes to work with multiple findlib directories in a single
  installation (#101 from Petter Urkedal).
* [xen] Install runtime headers for `mirage-xen` so that external C
  libraries can be compiled (#102 from James Bielman)
* [xen] Add support for demand-mapping for backend devices via a MiniOS
  gntmap device (#103).

## 1.1.1 (2013-02-24):
* xen: support 4096 event channels (up from 8). Each device typically
  uses one event channel.

## 1.1.0 (2013-02-01):
* Update to new io-page{,.unix} ocamlfind packages.
* Remove unused Netif module from Unix backend.
* Xen now depends on `xen-{evtchn,gnt}` packages.
* Add a `type 'a io` to make it easier to include with the Mirage sigs.

## 1.0.0 (2013-12-10):
* Set `Sys.os_type` to Unix in the Xen backend to help compatibility (#78).
* Suppress another dietlibc linker warning for vprintf in Xen.

## 0.9.9 (2013-12-07):
* Fix uninstall target for Unix.
* Remove `tuntap` stubs from Unix module; they are in `ocaml-tuntap` now.
* Move `OS.Clock` out to a toplevel `Clock` module (the `mirage-clock` package).
* Move `OS.Io_page` out to a toplevel `Io_page` module (the `io-page` package).
* Update library dependencies to reduce them based on new functionality.
* Install library as `mirage-xen` or `mirage-unix` that can coexist.
* Suppress dietlibc linker warnings for sscanf/sprintf.

## 0.9.8 (2013-11-07):
* Add support for OCaml 4.01.0 in addition to the existing 4.00.1 runtime.
* Major refresh of the NS3 simulation backend, for latest APIs.
* Add `Netif` statistics counters per-packet.
* [xen] Fix multi-page ring support by granting the correct data pages.
* [unix] flush OS.Console file descriptor more often (#108).
* Fix regression in `Io_page.string_blit` with non-zero src offset (#71).

## 0.9.7 (2013-10-05):
* Add Travis continuous integration scripts.
* [xen] zero out freshly allocated io pages.
* [xen] correct reattach xenstore connection after resume.
* [xen] fix suspend/resume
* [xen] switch to interrupts (SCHEDOP_block) rather than polling (SCHEDOP_poll)
  to allow more than 128 event channels
* [xen] add Activations.after interface to help drivers avoid losing interrupts
* Fix build on older gcc (4.4) versions, as found in CentOS 6.4.

## 0.9.6 (2013-08-27):
* [xen] adapt to new xenstore interface which allows the same code
  to be compiled under Unix userspace and xen kernelspace

## 0.9.5 (2013-08-09):
* Add the `mir-rt` regression runner to `scripts/` (not installed).
* Unhook `mir-run` from the build, as Mirari replaces it.
* [xen] Port Netif to use the `Macaddr` module from `ocaml-ipaddr`.

## 0.9.4 (2013-08-07):
* [xen] add atomic load/store bindings for shared memory rings
* [xen] add atomic operations necessary for vchan
* [xen] expose memory barriers via Xenctrl ocamlfind package

## 0.9.3 (2013-07-18):
* [xen] Prevent spinning in `Activations.run` when a thread is blocked
  and then awakened.
* [xen] Gnt.grant_table_index is now an int, was an int32.
* [xen] Cleaned some C stubs files, mainly page_stubs.c
* [xen] Improved module Netif: The function create do not take a
  callback anymore, hidden some private function from the .mli.
* [unix] Add support for building and running on FreeBSD.

## 0.9.2 (2013-07-09):
* [xen] Add Netif test to wait for a fixed number of ring slots > 0
* [xen] Add Evtchn.close to Xen backend.
* [xen] Disable tree-loop-distribute-patterns to workaround crash with
  gcc-4.8.  Temporary fix until we isolate the bug.
* [xen] Improved the interface of Io_page, implement some missing bits
  in Gnt.
* [xen] Several modules now have an interface similar to the one in
  the libxc bindings for OCaml. This makes it possible to write one
  application that can be compiled for the UNIX or the Xen backend.

## 0.9.1 (2013-06-11):
* [xen] add mmap stubs to make the default Bigarray module happy.
* OS.Netif.create no longer creates the tuntap interface.  Hotplug events
  are generated from the mirari calling functions instead, removing the
  policy from this library.

## 0.9.0 (2013-05-22):
* [xen] Add a simple 'resume hook' mechanism for xen devices
* [xen] Update to new shared ring signature in 0.4.0
* [xen] Allow device providers to be added later
* [xen] Move the blkif implementation to ocaml-xen-block-driver
* [xen] Io_page.string_blit has now an interface similar to String.blit
* [xen] Console.write_s has been renamed Console.write_all
* [xen] Gnttab.unmap_exn now throws an exception on failure, like the
  xenctrl version. This makes it possible to run the same blkback code
  in kernelspace and userspace.

## 0.8.1 (2013-03-27):
* [xen] Fix the Xen block interface to wait for init correctly.

## 0.8.0 (2013-02-12):
* Remove `mir-build` script as the Mirari builder does its job now.
* [xen] add Str module C stubs, adapted to work in the Xen backend.

## 0.7.2 (2013-02-08):
* [xen] Fix the size of the start-of-day Xenstore and console rings.
* Quieten the verbosity of devices sleeping in Xen, to avoid console
  overflow situations.
* Install the packed `cmx` along with the `cmxa` to ensure that the
  compiler can do cross-module optimization (this is not a fatal error,
  but will impact performance if the `cmx` file is not present).

## 0.7.1 (2012-12-20):
* [unix] Update devices API to use Cstruct 0.6.0

## 0.7.0 (2012-12-20):
* [xen] Add support for VM suspend/resume/migrate
* [xen] Support for multiple network interfaces
* [xen] Use new shared-memory-ring, removing old builtin version.
  This is all OCaml except for the memory barrier assembly instructions.
* Update Cstruct to new API in 0.6.0

## 0.6.1 (2012-12-15):
* [xen] Add an unused ?dev parameter to Netif.create to match
  the UNIX version.
* [script] Add a mir-build script which converts a native output
  object into a Xen kernel.  It does command-line parsing to be
  compatible with other Xen outputs in the future (such as the
  kFreeBSD or Javascript backends, when they are ready).

## 0.6.0 (2012-12-11):
* [xen] refresh to ocaml-4.00.1 runtime.  You *must* use the
  correct OPAM switch to match versions, or bad things will
  happen when the resulting binary is run.

## 0.5.0 (2012-12-10):
* [xen] Fix spurious floating point exceptions on some machines.
* [ns3] Add NS3-based simulator backend.
* [unix] Add pcap-based Ethernet access in addition to tuntap.

## 0.4.1 (2012-11-04):
* [xen] fix incorrect reference counting in Io_pages that could
  potentially cause pages to be reused too early.
* [xen] move Xenstore protocol implementation out to a separate
  library that provides it as a functor.
* [unix] ignore SIGPIPE in the OS.Main.run function.

## 0.4.0 (2012-09-11):
* [xen] Add support for mapping and unmapping grant references
* [xen] Support Xen 4.2 reserved console and xenstore maps.
* [xen] Switch the Xenstore and console rings over to use cstruct.
* [xen] Add Evtchn virq interface for stub xenstored.
* [xen] Add Evtchn.unbind.
* [netif] fix checksum calculation code for odd-sized packets.

## 0.3.0 (2012-09-04):
* Initial public release.
