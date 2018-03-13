# Status update, March 2018

mirage-platform is currently undergoing major refactoring.  Please read
[this issue](https://github.com/mirage/mirage-platform/issues/199) for detailed
information.

The goal is to reuse the [ocaml-freestanding](https://github.com/mirage/ocaml-freestanding) work for the xen backend as well:
- `unix` moved to [mirage-unix](https://github.com/mirage/mirage-unix) (release pending) and switched to topkg and ocamlbuild
- `xen` and `bindings` subdirectories moved to [mirage-xen](https://github.com/mirage/mirage-xen) (release pending), also switched to topkg and ocamlbuild
- the remaining `xen-ocaml` and `xen-posix` subdirectories will be deprecated once the move to ocaml-freestanding is complete

# MirageOS

Mirage OS is a library operating system that constructs [unikernels](http://queue.acm.org/detail.cfm?id=2566628)
for secure, high-performance network applications across a variety
of cloud computing and mobile platforms.  Code can be developed on a normal OS
such as Linux or MacOS X, and then compiled into a fully-standalone,
specialised unikernel that runs under the [Xen](http://xen.org/) hypervisor.

Since Xen powers most public [cloud computing](http://en.wikipedia.org/Cloud_computing)
infrastructure such as [Amazon EC2](http://aws.amazon.com) or [Rackspace](http://rackspace.com/cloud),
this lets your servers run more cheaply, securely and with finer control than
with a full software stack.

Mirage uses the [OCaml](http://ocaml.org/) language, with libraries that
provide networking, storage and concurrency support that work under Unix during
development, but become operating system drivers when being compiled for
production deployment. The framework is fully event-driven, with no support for
preemptive threading.

This contains the OS bindings for the Mirage operating system, primarily
through an `OS` OCaml module. The following backends are available:

* Unix: maps POSIX resources and executes Mirage apps as normal binaries.

* Xen: a microkernel backend that can run against Xen3+

For documentation, visit <http://openmirage.org>.

The older "unified" tree is also present for historical reasons into the
`old-master` branch.

### Repository Contents

- `xen-posix/` contains the header files to pretend a posix
  system (required to compile the OCaml runtime), plus minilibc and
  float formating -- this is the home for the `mirage-xen-posix` OPAM
  package. Installation goes into `.opam/x/lib/mirage-xen-posix` and
  `.opam/x/include/mirage-xen-posix`

- `xen-ocaml/` contains only the OCaml runtime (patches and build system),
  installation into `.opam/x/lib/mirage-xen-ocaml` and
  `.opam/x/include/mirage-xen-ocaml`

- `bindings/` and `xen/` subdirectories form the `mirage-xen` OPAM  package --
  this consists of various bindings and the OCaml OS module (in xen/).
