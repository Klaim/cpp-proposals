DOCUMENTS = \
  p0222r0-anonymous-struct-return.html \
  p0223r0-class-namespace.html \
  p0224r0-implicit-return-type.html \
  p0311r0-tuple-like-unified-vision.html \
  p0535r0-generalized-unpacking.html \
  p0536r0-implicit-return-and-anonymous-structs.html \
  p0537r0-instantiation-attributes.html \
  p0538r0-preprocessor-once.html

%.html: %.rst
	rst2html "$<" "$@"

all: $(DOCUMENTS)
