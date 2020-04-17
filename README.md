# DITA-fix-xbook-html-links

## Introduction

The introduction of scoped keys in DITA 1.3 allows cross-book references (also called cross-*deliverable* references) to be represented in DITA content. However, the DITA-OT does not yet provide out-of-the-box publishing support for such references.

This repo provides a DITA-OT plugin and a perl post-processing script that, when used together, can resolve cross-book links in the DITA-OT's HTML5 output.

For more information on scoped keys, see 
[*DITA 1.3 Feature Article: Understanding Scoped Keys in DITA 1.3*](https://www.oasis-open.org/committees/download.php/56472/Understanding%20Scoped%20Keys%20In%20DITA%201.3.pdf).

## How It Works

For a post-processing solution to work, we need both the *key references* and *key definitions* to be preserved in the published HTML5 output.

The provided DITA-OT plugin does the following:

* To preserve key *references*, the plugin copies scoped `@keyref` attributes of `<xref>` and `<link>` elements (and their specializations) to an HTML5 `@data-keyref` user attribute:

  ```
  <p class="p">See <span class="xref" data-keyref="B.topic_B">this topic in book B</span>.</p>
  ```

  Note that although the DITA-OT published this `<xref>` as an HTML5 `<span>` (because the target could not be resolved during publishing), the `@data-keyref` attribute remains.

* To preserve key *definitions*, the plugin copies a "keys-only" version of the final DITA map to each output directory:

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

  This "keys-only" map file contains the `@keys`/`@href` definition pairs **after all filtering and chunking has been applied**:

  ```
  % cat out/bookA/keys-bookA.ditamap
  <map>
     <title>Book A Online Help</title>
     <topicref keys="topic1" href="bookA_content/topic1.dita"/>
     <topicref keys="topic2" href="bookA_content/topic2.dita">
        <topicref keys="topic2a" href="bookA_content/topic2a.dita"/>
        <topicref keys="topic2b" href="bookA_content/topic2b.dita"/>
     </topicref>
  </map>
  ```

The `.dita` files in the final map correspond directly to `.html` or `.htm` files in the HTML5 output.

After all deliverables are published, the provided perl script post-processes the `<span @data-keyref="scope.key">` elements into `<a @href="html_filename">` elements. The script also adjusts for relative filesystem path differences between referring and referenced HTML files, regardless of the directory structure of the published output.

Book scopes are matched against the output directory names first (to support multiple books published from a single map), then the map names (to handle simple cases).
  

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

You must install the following plugin from this repo in your DITA-OT:

```
plugins/com.oxygenxml.preserve.keyrefs/
```

### Installing

Download or clone the repository, then put its `bin/` directory in your search path so that the `fix_html_xbook_links.pl` utility is found in your search path.

For example, in the default bash shell, add this line to your `\~/.profile` file:

```
PATH=~/git/DITA-fix-html-xbook-links/bin:$PATH
```

Copy the plugin to your DITA-OT's `plugins/` directory, then run

```
dita --install
```

## Usage

This utility processes one or more directories containing HTML5 output from the DITA-OT, then modifies the files in-place to resolve cross-deliverable links.

Run the utility with no arguments or with `-help` to see the usage:

```
$ fix_html_xbook_links.pl
Usage:
      <html_dir> [<html_dir> ...]
            Set of directories containing HTML5 output from the DITA-OT
      --dry-run
            Process but don't modify files
      --keep-keyrefs
            Keep @data-keyref attributes in HTML (to allow for future incremental updates)
```

To post-process content, specify one or more directory names that contain all the published output:

```
fix_html_xbook_links.pl ./out
```

You do not need to specify every deliverable output directory individually. The utility recursively searches for keys-*bookname*.ditamap files, then equates those subdirectories with that book's content.

The `--dry-run` option runs the processing and emits all messages, but does not modify any files. Use this first to check for missing or ambiguous (multiple-match) references.

The `--keep-keyrefs` option keeps the @data-keyref attributes in the HTML5 files, which allows for incremental processing when updated or additional HTML5 files become available. For example, you might republish only bookC with an updated content structure, and you want to be able to reprocess bookA and bookB in-place to reflect the new structure of bookC.

## Examples

[Click here](./example/) to see the included example.

## Implementation Notes

The `<span>...</span>` elements are replaced with `<xref>...</xref>` elements using regular-expression substitution. I tried various HTML parsing solutions, but they didn't work, or they significantly degraded the file structure, or they were very slow. However, this results in the unfortunate limitation that I cannot support nested `<span>` elements within the cross-reference `<span>` element. I'm sure it's possible in regex, but I'm not very good with recursive regular expressions.

## Limitations

Note the following limitations of this script and this flow:

* Scopes inside a map (`bookname.scopename.keyname`) are not supported.
* The cross-book scope names must match either the book map names or the output directory names.
* In the HTML5 files, cross-book `<span>` elements cannot contain nested `<span>` elements within them or the regex substitution produces unmatched tags.
* The plugin creates keys-*bookname*.ditamap files for all output types, not just HTML5 output types.
* Although the keys-only map files contain the original `<mapref>` references, the information is not used or cross-checked for consistency.
* The DITA-OT produces error messages for cross-book resource-only map references, but they seem to be harmless.

## Acknowledgments

These utilities would not be possible without help from:

* [Synopsys Inc.](https://www.synopsys.com/) (my employer), for allowing me to share my work with the DITA community.
* [Radu Coravu](https://www.google.com/search?q=radu+coravur+dita+oxygen), for giving me so many answers about DITA-OT plugins that he practically wrote this plugin himself.
* [Eliot Kimber](https://www.google.com/search?q=eliot+kimber+dita), for helping me understand the processing pipeline inside the DITA-OT.
