#!/usr/bin/perl
#
# build_script_files_from_spreadsheets.pl
# Build script data files from translated spreadsheets for the game "Yuuwaku" (Temptation).
#
# Written by Derek Pascarella (ateam)

# Include necessary modules.
use utf8;
use strict;
use File::Copy;
use Text::Unidecode;
use HTML::Entities;
use String::HexConvert ':all';
use Spreadsheet::ParseXLSX;
use Spreadsheet::Read qw(ReadData);

# Store input/output paths.
my $original_script_input_folder = "/mnt/z/fm_towns/disc_images/Yuuwaku/disc_image_extracted/";
my $spreadsheet_input_folder = "/mnt/z/fm_towns/disc_images/Yuuwaku/script/xlsx_translated/";
my $new_script_output_folder = "/mnt/z/fm_towns/disc_images/Yuuwaku/disc_image_extracted_new/";

# Initialize critical error counter.
my $critical_errors = 0;

# Read spreadsheet input directory of script files.
opendir(DIR, $spreadsheet_input_folder);
my @translated_spreadsheets = grep !/^\.\.?$/, readdir(DIR);
@translated_spreadsheets = sort { no warnings; $a <=> $b || $a cmp $b } @translated_spreadsheets;
closedir(DIR);

# Iterate through each translated spreadsheet in source folder.
for(my $i = 0; $i < scalar(@translated_spreadsheets); $i ++)
{
	# Store script data filename.
	(my $output_file = $translated_spreadsheets[$i]) =~ s/\.xlsx//g;

	# Read and store spreadsheet.
	my $spreadsheet = ReadData($spreadsheet_input_folder . "/" . $translated_spreadsheets[$i]);
	my @spreadsheet_rows = Spreadsheet::Read::rows($spreadsheet->[1]);

	# Status message.
	print "====================================================\n";
	print "[" . $output_file . "]\n";
	print "Performing sanity check...\n";

	# Iterate through spreadsheet to perform sanity check.
	for(my $i = 1; $i < scalar(@spreadsheet_rows); $i ++)
	{
		# Store datapoints on text entry.
		my $offset = int($spreadsheet_rows[$i][0]);
		my $bytes = int($spreadsheet_rows[$i][1]);
		my $type = $spreadsheet_rows[$i][2];
		my $japanese_text = decode_entities($spreadsheet_rows[$i][3]);
		my $english_text = decode_entities($spreadsheet_rows[$i][4]);
		(my $notes = decode_entities($spreadsheet_rows[$i][5])) =~ s/\n/ /g;

		# Throw warning if English text exceeds available space.
		if(length($english_text) > $bytes)
		{
			# Status message.
			print "WARNING: Offset " . $offset . " / Row " . ($i + 1) . " - English text exceeds available space.\n";

			# Increase critical error counter by one.
			$critical_errors ++;
		}

		# Store hex representation of original Shift-JIS-encoded Japanese text.
		my $japanese_hex = ascii_to_hex(Encode::encode("shiftjis", $japanese_text));
		$japanese_hex =~ s/^3f//gi;

		# If original Japanese text entry is monologue but English translation isn't, throw warning.
		if($japanese_hex =~ /^8140/ && $japanese_hex !~ /^81408175/ && $japanese_hex !~ /^81408169/ &&
		   $english_text !~ /^\(/ && (int($type) == 1 || $type eq "X"))
		{
			# Status message.
			print "WARNING: Offset " . $offset . " / Row " . ($i + 1) . " - English text should be monologue (NOTES: " . $notes . ").\n";
		}

		# If original Japanese text entry is spoken dialogue but English translation is monologue, throw warning.
		if($japanese_hex =~ /^81408175/ && $english_text =~ /^\(/)
		{
			# Status message.
			print "WARNING: Offset " . $offset . " / Row " . ($i + 1) . " - English text should be dialogue (NOTES: " . $notes . ").\n";
		}
	}

	# Status message.
	print "Patching script data...\n";

	# Copy original script data file to output folder.
	copy($original_script_input_folder . "/" . $output_file, $new_script_output_folder . "/" . $output_file);

	# Read in data for patching.
	my $patched_file_hex = &read_bytes($new_script_output_folder . "/" . $output_file);

	# Iterate through spreadsheet to process patching of each text entry.
	for(my $i = 1; $i < scalar(@spreadsheet_rows); $i ++)
	{
		# Store datapoints on text entry.
		my $offset = int($spreadsheet_rows[$i][0]);
		my $bytes = int($spreadsheet_rows[$i][1]);
		my $type = $spreadsheet_rows[$i][2];
		my $japanese_text = decode_entities($spreadsheet_rows[$i][3]);
		my $english_text = decode_entities($spreadsheet_rows[$i][4]);

		# Clean English text.
		$english_text =~ s/？？？/\?\?\? /g;
		$english_text =~ s/！！！/\!\!\! /g;
		$english_text =~ s/？/\? /g;
		$english_text =~ s/！/\! /g;
		$english_text =~ s/ +/ /;
		$english_text =~ s/\s+/ /g;
		$english_text =~ s/’/'/g;
		$english_text =~ s/”/"/g;
		$english_text =~ s/“/"/g;
		$english_text =~ s/\P{IsPrint}//g;
		$english_text =~ s/[^[:ascii:]]+//g;

		# Store hex representation of ASCII-encoded English text.
		my $english_hex = ascii_to_hex($english_text);

		# Store length of English string.
		my $english_length = length($english_text);

		# Replace "$$" with Shift-JIS-encoded "¥".
		$english_hex =~ s/202424/20818F/gi;

		# Pad English text hex data to fill available space.
		for($english_length .. $bytes - 1)
		{
			$english_hex .= "20";
		}

		# Patch original data with new data.
		substr($patched_file_hex, $offset * 2, length($english_hex)) = $english_hex;
	}

	# Quick fix for line that starts with "¥200,000 is all I can spare right now."
	if($translated_spreadsheets[$i] eq "N_OPEN_.BIN.xlsx" &&
	   $patched_file_hex =~ /00095B2B24243230/i)
	{
		$patched_file_hex =~ s/00095B2B24243230/00095B2B818F3230/gi;

		# Status message.
		print "Fixed yen sign text.\n";
	}

	# Quick fix for "ARCADE" menu entry.
	if($patched_file_hex =~ /B9DEB0D1BEDDC0B0/i)
	{
		$patched_file_hex =~ s/B9DEB0D1BEDDC0B0/4152434144452020/gi;

		# Status message.
		print "Fixed a missing \"ARCADE\" menu entry.\n";
	}

	# Quick fix for "GYM" menu entry.
	if($patched_file_hex =~ /CCA8AFC4C8BDB8D7CCDE/i)
	{
		$patched_file_hex =~ s/CCA8AFC4C8BDB8D7CCDE/47594D20202020202020/gi;

		# Status message.
		print "Fixed a missing \"GYM\" menu entry.\n";
	}

	# Quick fix for "AHEAD" (up arrow).
	if($patched_file_hex =~ /914F5C6600/i)
	{
		$patched_file_hex =~ s/914F5C6600/81AA5C6600/gi;

		# Status message.
		print "Fixed a missing \"AHEAD\" (up arrow) menu entry.\n";
	}

	# Quick fix for "BEHIND" (down arrow).
	if($patched_file_hex =~ /8CE35C6600/i)
	{
		$patched_file_hex =~ s/8CE35C6600/81AB5C6600/gi;

		# Status message.
		print "Fixed a missing \"BEHIND\" (down arrow) menu entry.\n";
	}

	# Quick fix for "LEFT" (left arrow).
	if($patched_file_hex =~ /89455C6600/i)
	{
		$patched_file_hex =~ s/89455C6600/81A95C6600/gi;

		# Status message.
		print "Fixed a missing \"LEFT\" (left arrow) menu entry.\n";
	}

	# Quick fix for "RIGHT" (right arrow).
	if($patched_file_hex =~ /8DB65C6600/i)
	{
		$patched_file_hex =~ s/8DB65C6600/81A85C6600/gi;

		# Status message.
		print "Fixed a missing \"RIGHT\" (right arrow) menu entry.\n";
	}

	# Quick fix for "ART BOOK".
	if($patched_file_hex =~ /BDB9AFC1CCDEAFB85C66/i)
	{
		$patched_file_hex =~ s/BDB9AFC1CCDEAFB85C66/41525420424F4F4B5C66/gi;

		# Status message.
		print "Fixed a missing \"ART BOOK\" menu entry.\n";
	}

	# Quick fix for broken speaker name label control code in N_JIMU_2.BIN.
	if($patched_file_hex =~ /5C6600099707/i)
	{
		$patched_file_hex =~ s/5C6600099707/5C6E00099707/gi;

		# Status message.
		print "Fixed broken speaker name label control code.\n";
	}

	# Quick fix for "DESK" in N_BDAI_6.BIN.
	if($patched_file_hex =~ /8AF75C660000/i)
	{
		$patched_file_hex =~ s/8AF75C660000/4445534B2020/gi;

		# Status message.
		print "Manually added oversized \"DESK\" menu entry.\n";
	}

	# Quick fix for "BACK" in N_KOEN_2.BIN.
	if($patched_file_hex =~ /899C5C660000/i)
	{
		$patched_file_hex =~ s/899C5C660000/504154482020/gi;

		# Status message.
		print "Manually added oversized \"BACK\" menu entry.\n";
	}

	# Quick fix to restore speaker name label to last line in N_JIMU_4.BIN and N_JIMU_7.BIN.
	if($translated_spreadsheets[$i] eq "N_OPEN_.BIN.xlsx" &&
	   $patched_file_hex =~ /CD0381405C6E0009E90328536967682E2E2E2920202020202020202020202020/i)
	{
		$patched_file_hex =~ s/CD0381405C6E0009E90328536967682E2E2E2920202020202020202020202020/CE034B594F5C6E0009E90328536967682E2E2E29202020202020202020202020/gi;
	
		# Status message.
		print "Fixed missing \"KYO\" speaker name label.\n";
	}

	# Quick fix to restore speaker name label to last line in N_JIMU_4.BIN and N_JIMU_7.BIN.
	if($translated_spreadsheets[$i] =~ /N_JIMU_[4|7]/ &&
	   $patched_file_hex =~ /45682C20646F6E277420626F746865722E204E6F74206D756368206861732068617070656E65642E2E2E2020/i)
	{
		$patched_file_hex =~ s/45682C20646F6E277420626F746865722E204E6F74206D756368206861732068617070656E65642E2E2E2020/4B594F5C6E45682C20646F6E277420626F746865722E204E6F74206D75636820686173206368616E6765642E/gi;
	
		# Status message.
		print "Fixed missing \"KYO\" speaker name label.\n";
	}

	# Quick fix to restore speaker name label in N_ETC files.
	if($translated_spreadsheets[$i] =~ /N_ETC_/ &&
	   $patched_file_hex =~ /182849276C6C206A7573742068616E67206865726520666F72206E6F772E29202020202020/i)
	{
		$patched_file_hex =~ s/182849276C6C206A7573742068616E67206865726520666F72206E6F772E29202020202020/184B594F5C6E2849276C6C206A7573742068616E67206865726520666F72206E6F772E2920/gi;

		# Status message.
		print "Fixed missing \"KYO\" speaker name label.\n";
	}

	# Quick fix to restore speaker name label in N_YASI_A.
	if($translated_spreadsheets[$i] =~ /N_YASI_A/ &&
	   $patched_file_hex =~ /0C284865792C2063616E207468657920736565206D653F292020202020/i)
	{
		$patched_file_hex =~ s/0C284865792C2063616E207468657920736565206D653F292020202020/0C4B594F5C6E284865792C2063616E207468657920736565206D653F29/gi;

		# Status message.
		print "Fixed missing \"KYO\" speaker name label.\n";
	}

	# Write patched data.
	&write_bytes($new_script_output_folder . "/" . $output_file, $patched_file_hex);

	# Status message.
	print "Script data patching complete!\n";

	# Include final linebreak if processing the last spreadsheet.
	if($i == scalar(@translated_spreadsheets) - 1)
	{
		# Status message.
		print "====================================================\n";
	}
}

# If one or more critical errors were encountered, display warning message.
if($critical_errors > 0)
{
	print "\nWARNING: A total of " . $critical_errors . " critical error(s) were encountered!\n";
}

# Subroutine to read a specified number of bytes (starting at the beginning) of a specified file,
# returning hexadecimal representation of data.
#
# 1st parameter - Full path of file to read.
# 2nd parameter - Number of bytes to read (omit parameter to read entire file).
sub read_bytes
{
	my $input_file = $_[0];
	my $byte_count = $_[1];

	if($byte_count eq "")
	{
		$byte_count = (stat $input_file)[7];
	}

	open my $filehandle, '<:raw', $input_file or die $!;
	read $filehandle, my $bytes, $byte_count;
	close $filehandle;
	
	return unpack 'H*', $bytes;
}

# Subroutine to write a sequence of hexadecimal values to a specified file.
#
# 1st parameter - Full path of file to write.
# 2nd parameter - Hexadecimal representation of data to be written to file.
sub write_bytes
{
	my $output_file = $_[0];
	(my $hex_data = $_[1]) =~ s/\s+//g;
	my @hex_data_array = split(//, $hex_data);

	open my $filehandle, '>:raw', $output_file or die $!;
	binmode $filehandle;

	for(my $i = 0; $i < scalar(@hex_data_array); $i += 2)
	{
		my($high, $low) = @hex_data_array[$i, $i + 1];
		print $filehandle pack "H*", $high . $low;
	}

	close $filehandle;
}