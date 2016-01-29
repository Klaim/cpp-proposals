DOCUMENTS = \
  dxxxx-class-namespace.html \
  dxxxx-implicit-return-type.html \
  dxxxx-anonymous-struct-return.html

%.html: %.rst
	rst2html "$<" "$@"

all: $(DOCUMENTS)
