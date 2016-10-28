DOCUMENTS = \
  p0222r0-anonymous-struct-return.html \
  p0223r0-class-namespace.html \
  p0224r0-implicit-return-type.html \
  p0311r0-tuple-like-unified-vision.html \
  dxxxx-preprocessor-once.html

%.html: %.rst
	rst2html "$<" "$@"

all: $(DOCUMENTS)
