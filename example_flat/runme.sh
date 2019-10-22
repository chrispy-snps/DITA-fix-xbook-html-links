#!/bin/bash
rm -rf ./out
mkdir ./out
dita -i ./bookA.ditamap -f html5 -o out/bookA_dir
dita -i ./bookB.ditamap -f html5 -o out/bookB_dir
dita -i ./bookC.ditamap -f html5 -o out/bookC_dir
../bin/fix_html_xbook_links.pl --dita . --html ./out

