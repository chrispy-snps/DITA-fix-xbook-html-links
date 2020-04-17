## Example

To run the example, install the DITA-OT plugin, then run the following commands:

    cd ./example
    ./runme.sh

`runme.sh` contains the following commands:

```
dita -i dita/bookA.ditamap -f html5 -o out/bookA_dir
#            ^^^^^
# for map-based scope matching, use the map base name
# as the scope name

dita -i dita/bookB.ditamap -f html5 -o out/B/bookB1 --filter=bookB1.ditaval
dita -i dita/bookB.ditamap -f html5 -o out/B/bookB2 --filter=bookB2.ditaval
#                                            ^^^^^^
# for directory-based scope matching, use the output
# directory name as the cross-book scope name

../bin/fix_html_xbook_links.pl ./out
```

Note that

* bookA.ditamap produces a single output deliverable (bookA) and thus map-based scope names can be used.
* bookB.ditamap produces two output deliverables (bookB1, bookB2) and thus directory-based scope names must be used.

The output directory located here contains the post-processed output.

