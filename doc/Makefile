# Makefile template for building the Engineering standards document.

# Don't remove .tex or .dvi intermediate files.
.PRECIOUS: %.tex %.dvi

SOURCES=codestriker.sgml
DOCBOOK_DIR=.

# Definition of programs to use.
JADE=openjade
JADETEX=jadetex
DVIPDF=dvipdf
RM=/bin/rm -f
SCP=/usr/bin/scp -q

# String output by $(JADETEX) when there are undefined references.
UNDEFINED_REFERENCES=LaTeX Warning: There were undefined references

# Location of style sheet.
DOCBOOK_DSL=docbook.dsl
DOCBOOK_DSL_HTML=$(DOCBOOK_DSL)\#html
DOCBOOK_DSL_PRINT=$(DOCBOOK_DSL)\#print

# Target file
HTML_TARGETS=$(SOURCES:.sgml=.html)
TEX_TARGETS=$(SOURCES:.sgml=.tex)
RTF_TARGETS=$(SOURCES:.sgml=.rtf)
AUX_TARGETS=$(SOURCES:.sgml=.aux)
LOG_TARGETS=$(SOURCES:.sgml=.log)
DVI_TARGETS=$(SOURCES:.sgml=.dvi)
PDF_TARGETS=$(SOURCES:.sgml=.pdf)

# Build the html files from a docbook sgml file.
%.html: %.sgml $(DOCBOOK_DIR)/$(DOCBOOK_DSL)
	$(JADE) -t sgml -D $(DOCBOOK_DIR) \
                -d $(DOCBOOK_DSL_HTML) $< > $@
	@if [ -f t1.html ]; then cp t1.html $@ ; fi
	@if [ -f book1.html ]; then cp book1.html $@ ; fi

# Build a tex file from a docbook sgml file.
%.tex: %.sgml $(DOCBOOK_DIR)/$(DOCBOOK_DSL)
	$(JADE) -t tex -D $(DOCBOOK_DIR) -d $(DOCBOOK_DSL_PRINT) $<


# Build a tex file from a docbook sgml file.
%.rtf: %.sgml $(DOCBOOK_DIR)/$(DOCBOOK_DSL)
	$(JADE) -t rtf -D $(DOCBOOK_DIR) -d $(DOCBOOK_DSL_PRINT) $<

# Build a dvi file from a tex file.  Note if there are undefined
# references, re-run JADETEX twice to ensure toc is updated properly.
# Ugh.
%.dvi: %.tex
	$(JADETEX) $<
	@while grep "$(UNDEFINED_REFERENCES)" $*.log > /dev/null ; do \
            echo "Re-running $(JADETEX) to resolve references..." ; \
            $(JADETEX) $< ; \
            $(JADETEX) $< ; \
	done

# Build a pdf file from a dvi file.
%.pdf: %.dvi
	$(DVIPDF) $<

default: $(HTML_TARGETS) $(PDF_TARGETS) $(RTF_TARGETS)

clean:
	$(RM) $(PDF_TARGETS) $(HTML_TARGETS) $(TEX_TARGETS) $(DVI_TARGETS) \
              $(AUX_TARGETS) $(LOG_TARGETS) $(RTF_TAREGTS) *.html


