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
sudo cpanm install XML::Twig Acme::Tools utf8::all
```

#### DITA-OT HTML5 transformation modification
You must modify your DITA-OT HTML5 transformation to save key reference information in the output. (This is what the script uses to reconstruct the references.) To do this,

1. Find the topic.xsl file for the `html5` transform, usually located at
   ```
   <DITA-OT>/plugins/org.dita.html5/xsl/topic.xsl
   ```
2. Find the following template block:
   ```
   <xsl:template name="commonattributes">
   ```
3. At the end of this block, add the following template:
   ```
   <xsl:if test="contains(@class, ' topic/xref ')">
     <xsl:if test="@keyref">
       <xsl:attribute name="data-keyref" select="@keyref"/>
     </xsl:if>
   </xsl:if>
   ```
If you are using Oxygen, you can modify the file located at
```
<Oxygen dir>/frameworks/dita/DITA-OT3.x/plugins/org.dita.html5/xsl/topic.xsl
```
(assuming you have write permissions).

### Installing

Download or clone the repository, then put its `bin/` directory in your search path.

For example, in the default bash shell, add this line to your `\~/.profile` file:

```
PATH=~/DITA-fix-html-xbook-links/bin:$PATH
```

## Usage

This utility takes .ditamap files and published HTML5 files as input, then modifies the HTML5 files in-place to reconstruct cross-book links.

Run it with no arguments or with `-help` to see the usage:

```
$ fix_html_xbook_links.pl
Usage:
      [--dita <path1>,<path2>,...]
      [--dita <path1> --dita <path2> ...]
              One or more directory paths containing .ditamap files

      [--html <path1>,<path2>,...]
      [--html <path1> --html <path2> ...]
              One or more directory paths containing HTML output from the DITA-OT
```

The `--dita` option specifies a directory where top-level .ditamap files can be found. It **does** not recurse into subdirectories.

The `--html` option specifies a directory where published HTML5 files can be found. It **does** recurse into subdirectories.

Multiple directories can be specified using either comma separation or multiple options. Directory names with spaces are not supported.

For example,

```
fix_html_xbook_links.pl --dita /product1/dita --dita product2/dita --html ./out
```

## Operation

When the HTML5 transformation is modified as described above, the published HTML5 files capture scoped key references in a `@data-keyref` attribute:

```
<p class="p">See <span class="xref" data-keyref="B.topic_B">this topic in book B</span>.</p>
```

The script uses the .ditamap files to correlate the key reference to a DITA filename, then correlates this DITA filename to the matching HTML5 filename, then converts the `<span @data-keyref="scope.key">` element to an `<a @href="html_filename">` element (adjusted for relative path differences between the referring and referenced HTML files).

To correlate DITA files to HTML5 files, the script compares the following:

* The actual HTML5 filenames
* The relative DITA filenames contained in the .ditamap file

To be considered a match, the DITA file path components must be **entirely contained within** the HTML file path components, compared from right to left, starting with the filenames (with extension removed). For example,

```
" / path / to / output / bookA_dir / that_chapter / my_topic_123 [.html]"
                                   " that_chapter / my_topic_123 [.dita]"
```

## Examples

Two examples are provided. The "flat" example uses single input and output directories for the DITA and HTML5 files, and the "dirs" example uses multiple input and output DITA and HTML5 directories.

To run the examples, use the following commands:

    cd ./example_flat
    ./runme.sh

and

    cd ./example_dirs
    ./runme.sh

## Implementation Notes

The `<span>...</span>` elements are replaced with `<xref>...</xref>` elements using regular-expression substitution. I tried various HTML parsing solutions, but they didn't work, or they significantly degraded the file structure, or they were very slow.

The file path comparison code works by building arbitrarily nested hashes. This was a bit more complicated to code than an array-based approach, but it is far faster when thousands of files are processed (because hash collisions occur only when the leaf filenames collide).

## Limitations

Note the following limitations of the script:

* The map or bookmap files must have a scope value set at the top level of the map.
* Nested map files are not yet supported.
* DITA topic files must exist at or below the directory of their map file.
* In the HTML5 files, cross-book `<span>` elements cannot contain nested `<span>` elements within them or the regex substitution produces unmatched tags.
