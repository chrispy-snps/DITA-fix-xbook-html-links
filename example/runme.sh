#!/bin/bash
rm -rf ./out
mkdir ./out
dita -i dita/bookA.ditamap -f html5 -o out/bookA_dir
dita -i dita/bookB.ditamap -f html5 -o out/bookB_dir
dita -i dita/bookC.ditamap -f html5 -o out/bookC_dir
../bin/fix_html_xbook_links.pl --dita ./dita/ --html ./out

