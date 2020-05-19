#!/usr/bin/perl
# fix_html_xbook_links.pl - resolve cross-book links in DITA-OT HTML outputs
#
#
# This script requires that the following included DITA-OT plugin be installed:
#
#   com.synopsys.preserve.keyrefs
#
# Thanks to Radu Coravu @ SyncroSoft for all his help!
#
#

# Prerequisites:
# sudo apt-get install make cpanminus  (makes it much easier to install Perl modules)
# sudo cpanm install XML::Twig utf8::all

use strict;
use warnings;

use List::Util qw(min max sum0);
use utf8::all;
use Getopt::Long 'HelpMessage';
use File::Spec;
use File::Basename;
use File::Find;
use XML::Twig;

my $dry_run;

# parse command line arguments
GetOptions(
  'dry-run'      => \$dry_run,
  'help'         => sub { HelpMessage(0) }
  ) or HelpMessage(1);

my @html_dirs = @ARGV;
if (!@html_dirs) {
 print "Error: no HTML directories specified.\n";
 HelpMessage(1);
}
 

# see what keymap and HTML files we can find
my %html_files_in_dir = ();
my %html_file_for_base = ();
my %keymap_files = ();
{
 print "Searching for files...\n";
 my $current_dir;
 foreach my $dir (@html_dirs) {
  find({
   wanted => sub { $keymap_files{$File::Find::name} = '' if (m!keys-[^/]+\.ditamap$!i); return 1; },
   follow => 1 }, $dir);
 }
 print "  Found ".scalar(keys %keymap_files)." content directories.\n";

 foreach my $dir (map {File::Spec->rel2abs(dirname($_))} sort keys %keymap_files) {  # hash HTML files by keymap directory
  find({
   wanted => sub {
    if (m!\.html?$!i) {
     my $thisfile = File::Spec->rel2abs($File::Find::name);
     $html_files_in_dir{$dir}->{$thisfile} = '';
     my $basefile = ($thisfile =~ s!\.[^\.]+$!!r);
     $html_file_for_base{$basefile} = $thisfile;  # if you have a .htm and .html file of the same name, you deserve bad things
    }
    return 1; },
   follow => 1 }, $dir);
 }
 print "  Found ".sum0(map {scalar(%{$html_files_in_dir{$_}})} keys %html_files_in_dir)." HTML files.\n";
}


# read key map files
my $keymaps_twig = XML::Twig->new()->parse('<keymaps/>');
my $deliverables_twig = XML::Twig->new()->parse('<deliverables/>');
{
 my $count = 0;
 foreach my $keyfile (sort map {File::Spec->rel2abs($_)} keys %keymap_files) {
  my $keymap_elt = $keymap_files{$keyfile} = XML::Twig->new(
   twig_handlers => {
    '*[@keys]' => sub { $count++; return 1; },
   })->safe_parsefile($keyfile)->root;
  $keymap_elt->set_att('file', $keyfile);
  $keymap_elt->move('last_child', $keymaps_twig->root);

  my $output = File::Spec->rel2abs(dirname($keyfile));
  my $dirname = basename($output);
  my ($map) = (basename($keyfile) =~ m!keys-([^/]+)\.ditamap$!i);
  $deliverables_twig->root->insert_new_elt('last_child', 'deliverable' => {'map' => $map, 'dirname' => $dirname, 'output' => $output, '#keymap_elt' => $keymap_elt});
 }
 print "  Found $count key definitions.\n";
}
#$deliverables_twig->print(pretty_print => 'indented');
#$keymaps_twig->print(pretty_print => 'indented');



# define a subroutine to return the map for a given book keyscope
#
# Key resolution rules:
#
# * Output directory names (highest)
# * Map names (lowest)
my %cache = ();  # the scope namespace is global across the collection, so we can cache it globally
sub compute_href_from_scoped_keyref {
 my ($scoped_keyref) = @_;
 return $cache{$scoped_keyref} if defined($cache{$scoped_keyref});
 my ($book_scope, $key_value) = ($scoped_keyref =~ m!^([^\.]+)\.(.*)$!);
 my @deliverables = $deliverables_twig->root->children("deliverable[\@dirname='$book_scope' or \@map='$book_scope']");
 # apply book scope precedence here, if any
 if (scalar(@deliverables) > 1) {
  print "    Warning: Multiple deliverables match '$book_scope', using first match:\n";
  print sprintf("      original map name: '%s.ditamap', output directory name: '%s'\n", $_->att('map'), $_->att('dirname')) for @deliverables;
  @deliverables = ($deliverables[0]);
 }
 if (!@deliverables) {
  print "    Error: Could not resolve book scope '$book_scope'.\n";
  return ($cache{$scoped_keyref} = undef);
 }
 my @target_hrefs = ();
 foreach my $deliverable (@deliverables) {
  my $keymap_elt = $deliverable->att('#keymap_elt');
  if (my @topicrefs = $keymap_elt->descendants_or_self("*[\@keys =~ /\\b$key_value\\b/ and \@href]")) {
   my $href = File::Spec->rel2abs($topicrefs[0]->att('href'), dirname($keymap_elt->att('file')));

   # convert .dita href file to .htm/.html file of the same base name (and keep any #id suffix)
   my $href_base = ($href =~ s!\.dita(#[\w_]+)?$!!ir);
   if (defined($html_file_for_base{$href_base})) {
    (my $ext) = $html_file_for_base{$href_base} =~ m!(\.\w+)$!;
    push @target_hrefs, ($href =~ s!\.dita!${ext}!ir);
   } else {
    print "    Warning: Could not find HTML file for '$href'.\n";  # we have the output directory and keymap file but not the file
   }
  }
 }
 if (!@target_hrefs) {
  print "    Error: Could not resolve scoped key reference '$scoped_keyref'.\n";
  return ($cache{$scoped_keyref} = undef);
 }
 # apply href precedence here, if any
 if (scalar(@target_hrefs) > 1) {
  print "    Warning: Multiple key definitions matched '$scoped_keyref', using first match:\n";
  print "      ".File::Spec->abs2rel($_)."\n" for @target_hrefs;
  @target_hrefs = ($target_hrefs[0]);
 }
 return ($cache{$scoped_keyref} = $target_hrefs[0]);  # global scope namespace
}



print "Processing HTML files...\n";
my @warnings = ();
foreach my $keymap_elt ($keymaps_twig->root->children) {
 my $keymap_file = $keymap_elt->att('file');
 my $bookdir = File::Spec->rel2abs(dirname($keymap_file));
 print sprintf("  Processing '%s'...\n", basename($bookdir));
 my $updated_count = 0;
 my $omitted_count = 0;
 foreach my $html_file (sort keys %{$html_files_in_dir{$bookdir}}) {
  my $guts = read_entire_file($html_file);

  # this subroutine converts a scoped-keyref href, if possible
  my $regsub_process_keyref = sub {
   my ($srcdir, $href) = @_;
   if (my ($scoped_keyref) = $href =~ m!keyref://([^"']+)["']!) {
    if (defined(my $new_href = compute_href_from_scoped_keyref($scoped_keyref))) {
     $href = sprintf('="%s"', File::Spec->abs2rel($new_href, $srcdir));
     $updated_count++;
    } else {
     push @warnings, sprintf("Could not find '%s' referenced in '%s'.", $scoped_keyref, File::Spec->abs2rel($html_file));
     $omitted_count++;
    }
   } else { die 'key value expected'; }
   return $href;
  };

  $guts =~ s!(=[\s\n\r]*["']keyref://[^"']*["'])!$regsub_process_keyref->(dirname($html_file),$1)!gse;
  write_entire_file($html_file, $guts) if !$dry_run;
 }
 print "    Converted $updated_count keyrefs.\n" if $updated_count;
 print "    Warning: $omitted_count keyrefs not found.\n" if $omitted_count;
}

print "Processing complete.\n";
print "\n".join("\n", @warnings)."\n" if @warnings;
exit;



sub read_entire_file {
 my $filename = shift;
 open(FILE, "<$filename") or die "can't open $filename for read: $!";
 local $/ = undef;
 binmode(FILE, ":encoding(utf-8)");  # the utf8::all package checks and enforces this
 my $contents = <FILE>;
 close FILE;
 return $contents;
}

sub write_entire_file {
 my ($filename, $contents) = @_;
 open(FILE, ">$filename") or die "can't open $filename for write: $!";
 binmode(FILE, ":encoding(utf-8)");  # the utf8:all package checks and enforces this
 print FILE $contents;
 close FILE;
}




=head1 NAME

fix_html_xbook_links.pl - resolve cross-book links in DITA-OT HTML outputs

=head1 SYNOPSIS

  <html_dir> [<html_dir> ...]
        Set of directories containing HTML output from the DITA-OT
  -dry-run
        Process but don't modify files

=head1 VERSION

1.05

=cut

