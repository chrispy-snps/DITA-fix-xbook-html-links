#!/bin/bash
rm -rf ./out_A ./out_BC
mkdir ./out_A ./out_BC

dita -i dita_A/bookA.ditamap -f html5 -o out_A/bookA_dir
dita -i dita_B/bookB.ditamap -f html5 -o out_BC/bookB_dir
dita -i dita_C/bookC.ditamap -f html5 -o out_BC/bookC_dir

# can use comma-separated paths or multiple path options
../bin/fix_html_xbook_links.pl --dita ./dita_A,./dita_B,./dita_C --html out_A --html out_BC

