FROM unikernel/mirage
RUN opam install --deps-only mirage-xen mirage-unix -y
COPY build.sh /build.sh
