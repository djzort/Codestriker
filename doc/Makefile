# Makefile template for building the Codestriker documentation.

# Don't remove .tex or .dvi intermediate files.
.PRECIOUS: %.eps

SOURCES=codestriker.sgml
DOCBOOK_DIR=.

# Definition of programs to use.
JADE=openjade
JADETEX=jadetex
DVIPDF=dvipdf
DVIPS=dvips
RM=/bin/rm -f
CP=/bin/cp
PNG2PNM=pngtopnm
PNM2PS=pnmtops -noturn

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
PS_TARGETS=$(SOURCES:.sgml=.ps)

# List of PNG image files.
PNG_FILES=$(wildcard *.png)
EPS_FILES=$(PNG_FILES:.png=.eps)

# Build the html files from a docbook sgml file.
%.html: %.sgml $(DOCBOOK_DIR)/$(DOCBOOK_DSL)
	$(JADE) -t sgml -D $(DOCBOOK_DIR) \
                -d $(DOCBOOK_DSL_HTML) $< > $@
	@if [ -f t1.html ]; then cp t1.html $@ ; fi
	@if [ -f book1.html ]; then cp book1.html $@ ; fi

# Build a tex file from a docbook sgml file.
%.tex: %.sgml $(DOCBOOK_DIR)/$(DOCBOOK_DSL) $(EPS_FILES)
	$(JADE) -t tex -D $(DOCBOOK_DIR) -d $(DOCBOOK_DSL_PRINT) $<


# Build a tex file from a docbook sgml file.
%.rtf: %.sgml $(DOCBOOK_DIR)/$(DOCBOOK_DSL) $(EPS_FILES)
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

# Build a ps file from a dvi file.
%.ps: %.dvi
	$(DVIPS) -o $@ $<

# Build a EPS file from a PNG file.
%.eps: %.png
	$(PNG2PNM) $< | $(PNM2PS) > $@

install: $(HTML_TARGETS) $(PDF_TARGETS) $(EPS_FILES)
	$(CP) $(PDF_TARGETS) *.html *.png ../html

clean:
	$(RM) $(PDF_TARGETS) $(HTML_TARGETS) $(TEX_TARGETS) $(DVI_TARGETS) \
              $(PS_TARGETS) $(AUX_TARGETS) $(LOG_TARGETS) $(RTF_TAREGTS) \
              *.html $(EPS_FILES)


