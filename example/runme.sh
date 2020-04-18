#!/bin/bash
rm -rf ./out
mkdir ./out

dita -i dita/bookA.ditamap -f html5 -o out/bookA_dir -Dpreserve.keys=yes
#            ^^^^^
# for map-based scope matching, use the map base name
# as the scope name

dita -i dita/bookB.ditamap -f html5 -o out/B/bookB1 --filter=bookB1.ditaval -Dpreserve.keys=yes
dita -i dita/bookB.ditamap -f html5 -o out/B/bookB2 --filter=bookB2.ditaval -Dpreserve.keys=yes
#                                            ^^^^^^
# for directory-based scope matching, use the output
# directory name as the cross-book scope name

../bin/fix_html_xbook_links.pl ./out

