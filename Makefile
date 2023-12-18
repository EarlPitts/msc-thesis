.DEFAULT: render

render: convert
	biber thesis
	pdflatex  -interaction=nonstopmode thesis.tex

convert:
	for file in contents/*.md; do                                              \
		name=$$(basename $$file .md) 									      ;\
		pandoc --top-level-division=chapter "$$file" -o "contents/$$name.tex" ;\
	done

clean:
	rm texput.log
	rm thesis.aux
	rm thesis.bcf
	rm thesis.idx
	rm thesis.log
	rm thesis.nlo
	rm thesis.run.xml
	rm thesis.toc
