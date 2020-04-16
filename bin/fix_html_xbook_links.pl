#!/usr/bin/perl
# fix_html_xbook_links.pl - resolve cross-book links in DITA-OT HTML5 outputs
#
#
# This script requires that the following DITA-OT plugin be installed:
#
#   com.oxygenxml.preserve.keyrefs
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

my $verbose;
my $quiet;
my $dry_run;
my $keep_keyrefs;

# parse command line arguments
GetOptions(
  'verbose'      => \$verbose,
  'quiet'        => \$quiet,
  'dry-run'      => \$dry_run,
  'keep-keyrefs' => \$keep_keyrefs,
  'help'         => sub { HelpMessage(0) }
  ) or HelpMessage(1);

my @html_dirs = @ARGV;
if (!@html_dirs) {
 print "Error: no HTML directories specified.\n";
 HelpMessage(1);
}
 

# see what keymap and HTML files we can find
my %html_files = ();
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
   wanted => sub { $html_files{$dir}->{$File::Find::name} = '' if (m!\.html?$!i); return 1; },
   follow => 1 }, $dir);
 }
 print "  Found ".sum0(map {scalar(%{$html_files{$_}})} keys %html_files)." HTML files.\n";
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
# * Keymap names (lowest)
my %cache = ();
 sub compute_href_from_scoped_keyref {
  my ($scoped_keyref) = @_;
  return $cache{$scoped_keyref} if defined($cache{$scoped_keyref});  # global scope namespace

  my ($book_scope, $key_value) = ($scoped_keyref =~ m!^([^\.]+)\.(.*)$!);
  my @deliverables = $deliverables_twig->root->children("deliverable[\@dirname='$book_scope' or \@map='$book_scope']");

  # apply book scope precedence here, if any
  if (scalar(@deliverables) > 1) {
   if ($verbose) {
    print "Warning: Multiple deliverables match '$book_scope', using first match:\n";
    print "  ".$_->sprint."\n" for @deliverables;
   }
   @deliverables = ($deliverables[0]);
  }

  if (!@deliverables) {
   print "Error: Could not resolve book scope '$book_scope'.\n" if $verbose;
   return ($cache{$scoped_keyref} = undef);
  }

  my @target_hrefs = ();
  foreach my $deliverable (@deliverables) {
   my $keymap_elt = $deliverable->att('#keymap_elt');
   if (my @topicrefs = $keymap_elt->descendants_or_self("*[\@keys =~ /\\b$key_value\\b/ and \@href]")) {
    my $href = File::Spec->rel2abs($topicrefs[0]->att('href'), dirname($keymap_elt->att('file')));
    $href =~ s!\.dita!\.html!i;
    if (-f ($href =~ s!#.*$!!r)) {
     push @target_hrefs, $href;
    } else {
     print "Warning: Could not find '$href'\n." if $verbose;  # we have the output directory and keymap file but not the file
    }
   }
  }

  if (!@target_hrefs) {
   print "Error: Could not resolve scoped key reference '$scoped_keyref'.\n" if $verbose;
   return ($cache{$scoped_keyref} = undef);
  }

  # apply href precedence here, if any
  if (scalar(@target_hrefs) > 1) {
   if ($verbose) {
    print "Warning: Multiple key definitions matched '$scoped_keyref', using first match:\n";
    print "  ".File::Spec->abs2rel($_)."\n" for @target_hrefs;
   }
   @target_hrefs = ($target_hrefs[0]);
  }

  return ($cache{$scoped_keyref} = $target_hrefs[0]);  # global scope namespace
 }



print "Processing HTML files...\n";
my @warnings = ();
foreach my $keymap_elt ($keymaps_twig->root->children) {
 my $keymap_file = $keymap_elt->att('file');
 my $bookdir = File::Spec->rel2abs(dirname($keymap_file));
 print sprintf("  Processing '%s'...", basename($bookdir));
 my $updated_count = 0;
 my $omitted_count = 0;
 foreach my $html_file (sort keys %{$html_files{$bookdir}}) {
  my $guts = read_entire_file($html_file);

  # this subroutine converts a scoped keyref to an href, if possible
  my $regsub_process_keyref = sub {
   my ($srcdir, $element) = @_;
   $element =~ s!\s+(href|format|scope)\s*=\s*"[^"]*"!!gs;  # delete unused attributes
   if (my ($scoped_keyref) = $element =~ m!data-keyref=["']([^"']*)["']!) {
    if (defined(my $href = compute_href_from_scoped_keyref($scoped_keyref))) {
     $href = File::Spec->abs2rel($href, $srcdir);
     $element =~ s!(\s+data-keyref\s*=)! href="$href"$1!gs;
     $element =~ s!\s+data-keyref\s*=\s*"[^"]*"!!gs if !$keep_keyrefs;
     $element =~ s!^<span!<a!s;
     $element =~ s!</\s*span>$!</a>!s;
     $updated_count++;
    } else {
     push @warnings, sprintf("Could not find '%s' referenced in '%s'.", $scoped_keyref, File::Spec->abs2rel($html_file));
     $omitted_count++;
    }
   } else { die 'key value expected'; }
   return $element;
  };

  $guts =~ s!(<span[^>]+data-keyref=["'][^"']*["'][^>]*>.*?<\/span>)!$regsub_process_keyref->(dirname($html_file),$1)!gse;
  write_entire_file($html_file, $guts) if !$dry_run;
 }
 print " -- converted $updated_count keyrefs" if $updated_count;
 print " -- ***$omitted_count keyrefs NOT FOUND***" if $omitted_count;
 print "\n";
}

print "Processing complete.\n";
print "\n".join("\n", @warnings)."\n" if @warnings;
exit;



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

# sort and remove duplicates
sub distinct { return sort keys %{{map {($_ => 1)} @_}} }



=head1 NAME

fix_html_xbook_links.pl - resolve cross-book links in DITA-OT HTML5 outputs

=head1 SYNOPSIS

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

=head1 VERSION

0.20

=cut

