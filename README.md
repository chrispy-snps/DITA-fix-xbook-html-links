# DITA-fix-xbook-html-links

## Introduction

The introduction of scoped keys in DITA 1.3 allows cross-book references (also known as cross-*deliverable* references) to be represented in DITA content. However, the DITA-OT does not yet provide out-of-the-box publishing support for such references.

This script reconstructs cross-book links in the DITA-OT HTML5 output via post-processing.

For more information on scoped keys, see 
[*DITA 1.3 Feature Article: Understanding Scoped Keys in DITA 1.3*](https://www.oasis-open.org/committees/download.php/56472/Understanding%20Scoped%20Keys%20In%20DITA%201.3.pdf).
## Getting Started

You can run this script on a native linux machine, or on a Windows 10 machine that has Windows Subsystem for Linux (WSL) installed.

### Prerequisites

#### Perl

Before using this script, you must install the following perl modules:

```
sudo apt update
sudo apt install cpanminus
sudo cpanm install XML::Twig utf8::all
```

#### DITA-OT

You must install the following provided plugin in your DITA-OT:

```
plugins/com.oxygenxml.preserve.keyrefs/
```

### Installing

Download or clone the repository, then put its `bin/` directory in your search path.

For example, in the default bash shell, add this line to your `\~/.profile` file:

```
PATH=~/DITA-fix-html-xbook-links/bin:$PATH
```

## Usage

This utility processes one or more directories containing HTML5 output from the DITA-OT, then modifies the files in-place to resolve cross-deliverable links.

Run the utility with no arguments or with `-help` to see the usage:

```
$ fix_html_xbook_links.pl
Usage:
      <html_dir> [<html_dir> ...]
            Set of directories containing HTML5 output from the DITA-OT
      -verbose
            Show all ambiguity messages
      -quiet
            Supppress unresolved keyref messages
      -dry-run
            Process but don't modify files
      -keep-keyrefs
            Keep @data-keyref attributes in HTML (to allow for future incremental updates)
```

You can specify one or more output directory names. The directories are recursively searched for output. For example,

```
fix_html_xbook_links.pl out_set1/ out_set2/
```

The `-keep-keyrefs` option keeps the @data-keyref attributes in the HTML5 files, which allows for incremental processing when updated or additional HTML5 files become available.

## Operation

When the DITA-OT plugin above is installed, the published HTML5 files capture scoped key references in a `@data-keyref` attribute:

```
<p class="p">See <span class="xref" data-keyref="B.topic_B">this topic in book B</span>.</p>
```

In addition, the DITA-OT writes a keys-only mapfile into each output directory:

```
out/bookA/index.html
out/bookA/keys-bookA.ditamap
...book A content files...

out/bookB/index.html
out/bookB/keys-bookB.ditamap
...book B content files...

out/bookC/index.html
out/bookC/keys-bookC.ditamap
...book C content files...
```

This file contains the map's key definitions **after all filtering and chunking has been applied**. The .dita key targets correspond directly to `.html` or `.htm` files in the HTML5 output. This allows the script to convert the `<span @data-keyref="scope.key">` element to an `<a @href="html_filename">` element (adjusted for relative path differences between the referring and referenced HTML files).

Book scopes are matched against the output directory names first (to support multiple books published from a single map), then the map names (to handle simple cases).

## Examples

To run the examples, install the DITA-OT plugin, then run the following commands:

    cd ./example_simple_books
    ./runme.sh

    cd ./example_conditional_books
    ./runme.sh

## Implementation Notes

The `<span>...</span>` elements are replaced with `<xref>...</xref>` elements using regular-expression substitution. I tried various HTML parsing solutions, but they didn't work, or they significantly degraded the file structure, or they were very slow.


## Limitations

Note the following limitations of the script:

* Nested scopes in a map are not supported.
* The cross-book scope names must match either the book map names or the output directory names.
* In the HTML5 files, cross-book `<span>` elements cannot contain nested `<span>` elements within them or the regex substitution produces unmatched tags.
* The plugin creates keys-\<book\>.ditamap files for all output types, not just HTML5 output types.