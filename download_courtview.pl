#!/usr/bin/perl

# This uses fairly straightforward Firefox automation to download Alaska court records as web pages
# Some hangs and errors are to be expected with WWW::Mechanize::Firefox, so this script will require
# a supervisor and probably multiple passes
# It can be run in parallel in multiple virtual machines to achieve an acceptable download rate

# Usage:
#  perl download_courtview.pl --start=1 --end=20000 --prefix=3AN --year=2015 --criminal --directory=$HOME/data/courtview/raw

use strict;
use WWW::Mechanize::Firefox;
use Getopt::Long;

# Create the user agent
# Note: the below line sometimes crashes on a slow machine and may require a script restart (...)
my $mech = WWW::Mechanize::Firefox->new("launch" => "firefox", "tab" => "current");

# Set some defaults
my $prefix = "3AN";
my $year = `date '+%g'`;
chomp $year;
$year--;
my $criminal = 0;
my $start = 1;
my $end = 20000;
my $directory = ".";

# Parse command line options
my $result = GetOptions("prefix=s" => \$prefix, "year=i" => \$year, "criminal" => \$criminal, "start=i" => \$start, "end=i" => \$end, "directory=s" => \$directory);

chdir "$directory";

# Navigate to the Courtview search page
load_homepage();

# Iterate through the range of case numbers 
for(my $i = $start; $i <= $end; $i++)
{
	my $case_number = craft_case_number($prefix, $year, $i, $criminal);
	run_search("$case_number");
}

# Craft a case number from its components
sub craft_case_number
{
	my $prefix = shift;
	my $year = shift;
	my $serial = shift;
	my $criminal = shift;
	if($criminal) { $criminal = "CR"; } else { $criminal = "CI"; }
	$serial = "000000000$serial";
	$serial = substr($serial, -5);
	my $cn = "$prefix-$year-$serial$criminal";
	print "$cn\n";
	return $cn;
}

# Search for a court case by case number and cache the page, then navigate back to the search page
sub run_search
{
	my $case_id = shift;
	if(-f "$case_id.html")
	{
		print "$case_id.html exists\n";
		return;
	}
	$mech->field("#caseDscr", $case_id);
	$mech->click("submitLink");
	my @links = $mech->xpath('//a[@id="grid$row:1$cell:1$link"]');
	if(scalar(@links) < 1)
	{
		system "echo Not Found > $case_id.html";
		$mech->back();
		return;
	}
	$mech->click({"id"=>'grid$row:1$cell:1$link'});
	my $text = $mech->content();
	open OUT, ">$case_id.html";
	print OUT $text;
	close OUT;
	$mech->back();
	$mech->back();
}

# Load the search page
sub load_homepage
{
	$mech->get("http://www.courtrecords.alaska.gov/eservices/home.page.2");
	sleep 1;
	$mech->click({"xpath"=>'//a[@class="anchorButton"]'}, synchronize=>0);
	my @links;
	do
	{
		sleep 1;
		@links = $mech->xpathEx('//a[@name="submitLink"]');
	} while(scalar(@links) == 0);
	
}
