FILES=description.html

all: gen-html

gen-html: $(FILES)

.SUFFIXES: .rd .html

.rd.html:
	rd2 -r rd/rd2html-lib -r rd/rd2html-ext-lib --html-lang=ja --html-charset=utf-8 $< > $@
