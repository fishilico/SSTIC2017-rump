SRC = presentation.tex
PDF = presentation.pdf

MDSRC := $(wildcard *.md)
TEXSRC := $(MDSRC:%.md=%.tex)

all: $(PDF)

$(PDF): beamerthemepolytechniqueorg.sty $(SRC) $(TEXSRC)
	latexmk -xelatex -shell-escape $(SRC) < /dev/null

%.tex: %.md
	pandoc -t beamer --slide-level 2 --latex-engine=xelatex --listings --highlight-style=pygments -o $@ $<

clean:
	$(RM) $(PDF) *.aux *.fdb_latexmk *.fls *.log *.nav *.out *.snm *.toc $(TEXSRC)
	$(RM) -r _minted-presentation/

.PHONY: all clean
