FROM unikernel/mirage
RUN opam install --deps-only mirage-xen -y
COPY build.sh /build.sh
