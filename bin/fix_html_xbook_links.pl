#!/usr/bin/perl
# fix_html_xbook_links.pl - post-process DITA-OT HTML output to resolve cross-book links
#
#
# This script requires that the following template:
#
#   <xsl:if test="contains(@class, ' topic/xref ')">
#     <xsl:if test="@keyref">
#       <xsl:attribute name="data-keyref" select="@keyref"/>
#     </xsl:if>
#   </xsl:if>
#
# be placed at the end of
#
#   <xsl:template name="commonattributes">
#
# in the following file:
#
#   <DITA-OT>/plugins/org.dita.html5/xsl/topic.xsl
#
# Thanks to Radu Coravu @ SyncroSoft for this XSLT!
#
#

# Prerequisites:
# sudo apt-get install make cpanminus  (makes it much easier to install Perl modules)
# sudo cpanm install XML::Twig utf8::all

use strict;
use warnings;

use Getopt::Long 'HelpMessage';
use XML::Twig;
use utf8::all;
use File::Basename;


# parse command line arguments
my @ditapaths;
my @htmlpaths;

GetOptions(
  'dita=s@'  => \@ditapaths,
  'html=s@'  => \@htmlpaths,
  'help'    => sub { HelpMessage(0) }
  ) or HelpMessage(1);

if (!@ditapaths || !@htmlpaths) {
 print "Error: --dita is a required option.\n" if !@ditapaths;
 print "Error: --html is a required option.\n" if !@htmlpaths;
 HelpMessage(1);
}

@ditapaths = split(/,/, join(',', @ditapaths));  # accept multiple options or comma-separated paths
@htmlpaths = split(/,/, join(',', @htmlpaths));

# acquire key/topic file pairs from all ditamaps
my %topicfile_for_key = ();
(my @ditamap_files = map {glob "$_/*.ditamap"} @ditapaths) or die "No .ditamap files found.";
print "Acquiring topic information from ditamaps...\n";
foreach my $mapfile (@ditamap_files) {
 my $twig = XML::Twig->new(
  twig_handlers => {
   '*[@href and @keys]' => sub {
    my $book = $_->inherit_att('keyscope') or die '@keyscope must be defined on the top-level <map> or <bookmap>';
    my $scoped_key = $book.'.'.$_->att('keys');
    $topicfile_for_key{$scoped_key} = $_->att('href');
    return 1; },
  }
 )->parsefile($mapfile);
}

# get a list of HTML files with unresolved key references
(my @html_files = map {split /\s+/, `fgrep --files-with-matches 'data-keyref=' --recursive $_`} @htmlpaths) or die "No HTML files found.";
print "Acquiring HTML files with unresolved cross-book links...\n";

# associate topic files with HTML files
my %htmlfile_for_key = ();
{
 my $pathhash = {};
 foreach my $key (keys %topicfile_for_key) {
  my $thishash = $pathhash;
  my @paths = ((reverse split(/\//, $topicfile_for_key{$key} =~ s!\.dita$!!r)));
  $thishash = ($thishash->{$_} or ($thishash->{$_} = {})) for @paths;
  $thishash->{'key'} = $key;
 }

 HTML: foreach my $html_file (@html_files) {
  my @paths = ((reverse split(/\//, $html_file =~ s!\.html$!!r)));
  my $thishash = $pathhash;
  foreach my $path (@paths) {
   ($thishash = $thishash->{$path}) or next HTML;
   if (defined($thishash->{'key'})) {
    $htmlfile_for_key{$thishash->{'key'}} = $html_file;
    next HTML;
   }
  }
 }
}

# process HTML files
foreach my $file (@html_files) {
 my $guts = read_entire_file($file);
 my $updated_count = 0;

 my $process_keyref = sub {
  my ($srcdir, $element) = @_;
  if (my ($key) = $element =~ m!data-keyref=["']([^"']*)["']!) {
   if (defined($htmlfile_for_key{$key})) {
    $key = File::Spec->abs2rel($htmlfile_for_key{$key}, $srcdir);
    $element =~ s!^<span!<a!s;
    $element =~ s!span>$!a>!s;
    $element =~ s!data-keyref=["'][^"']*["']!href="$key" from-keyref="true"!s;
    $updated_count++;
   }
  }
  return $element;
 };

 $guts =~ s!(<span[^>]+data-keyref=["'][^"']*["'][^>]*>.*?<\/span>)!$process_keyref->(dirname($file),$1)!gse;
 print "Updated $updated_count xrefs in '$file'.\n" if $updated_count;
 write_entire_file($file, $guts);
}


sub read_entire_file {
 my $filename = shift;
 open(FILE, "<$filename") or die "can't open $filename for read: $!";
 local $/ = undef;
 binmode(FILE, ":encoding(utf-8)");  # the UTF-8 package checks and enforces this
 my $contents = <FILE>;
 close FILE;
 return $contents;
}

sub write_entire_file {
 my ($filename, $contents) = @_;
 open(FILE, ">$filename") or die "can't open $filename for write: $!";
 binmode(FILE, ":encoding(utf-8)");  # the UTF-8 package checks and enforces this
 print FILE $contents;
 close FILE;
}


=head1 NAME

fix_html_xbook_links.pl - show content model of DITA topicshell or mapshell module

=head1 SYNOPSIS

  [--dita <path1>,<path2>,...]
  [--dita <path1> --dita <path2> ...]
          One or more directory paths containing .ditamap files

  [--html <path1>,<path2>,...]
  [--html <path1> --html <path2> ...]
          One or more directory paths containing HTML output from the DITA-OT

=head1 VERSION

0.10

=cut

