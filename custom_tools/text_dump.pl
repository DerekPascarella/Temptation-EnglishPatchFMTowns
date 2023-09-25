#!/usr/bin/perl
#
# text_dump.pl
# Generate raw text dumps for the game "Yuuwaku" (Temptation) using TextScan
# (https://www.romhacking.net/utilities/1164/).
#
# Written by Derek Pascarella (ateam)

# Include necessary modules.
use strict;

# Define paths.
my $disc_image_extracted_folder = "Z:\\fm_towns\\disc_images\\Yuuwaku\\disc_image_extracted\\";
my $text_dump_output_folder = "Z:\\fm_towns\\disc_images\\Yuuwaku\\script\\txt_original\\";
my $textscan_location = "TextScan.exe";
my $shift_jis_table = "sjis.tbl";

# Store each file from extracted disc image into an element of "files" array.
opendir(DIR, $disc_image_extracted_folder);
my @files = grep !/^\.\.?$/, readdir(DIR);
closedir(DIR);

# Iterate through each file.
foreach(@files)
{
	# Only process .BIN files, excluding "CINEMA.BIN" and "N_START.BIN".
	if($_ =~ /\.BIN/ && $_ ne "CINEMA.BIN" && $_ ne "N_START.BIN")
	{
		# Invoke TextScan.exe to perform text dump.
		system "$textscan_location \"$disc_image_extracted_folder\\$_\" $shift_jis_table -l 2 -e shift_jis -o \"$text_dump_output_folder\\$_\.txt\"";
	}
}