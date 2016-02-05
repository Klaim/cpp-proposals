DOCUMENTS = \
  d0222-anonymous-struct-return.html \
  d0223-class-namespace.html \
  d0224-implicit-return-type.html

%.html: %.rst
	rst2html "$<" "$@"

all: $(DOCUMENTS)
