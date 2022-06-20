# pdf-splitter

A bash script that splits pdfs into 2 files making printing multiple pages on one sheet of paper easier with a printer that can't print on both sides of the paper. 

## Usage
Use the `-p` option to specify how many pages of the pdf you want on one physical page, followed by the location of the pdf you want to split. The script will then generate 2 files called `frontPages.pdf` and `backPages.pdf`. You have to print out `frontPages.pdf` first with the same amount of pages as provided earlier to `-p`. Finally flip the pages and put it back in your printer, but this time print `backPages.pdf` the same way you printed `frontPages.pdf`.
