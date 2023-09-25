#!/usr/bin/perl
#
# generate_spreadsheets.pl
# Generate spreadsheets from text dumps performed by text_dump.pl for the game "Yuuwaku" (Temptation).
#
# Written by Derek Pascarella (ateam)

# Include necessary modules.
use strict;
use utf8;
use ShiftJIS::String;
use String::HexConvert ':all';
use Encode qw(decode encode);
use Spreadsheet::WriteExcel;
use HTTP::Tiny;
use JSON;
use URI::Encode qw(uri_encode uri_decode);
use HTML::Entities;

# Store input/output paths.
my $script_input_folder = "/mnt/z/fm_towns/disc_images/Yuuwaku/script/txt_original/";
my $spreadsheet_output_folder = "/mnt/z/fm_towns/disc_images/Yuuwaku/script/xls_original/";

# Store DeepL API key for machine translations.
my $deepl_api_key = "fill_me_in";

# Open name list to populate hash.
my %names;
open(FH, '<', "names.txt") or die $!;
while(<FH>)
{
	chomp;
	my $name_japanese = (split /\|/, $_)[0];
	my $name_english = (split /\|/, $_)[1];
	$names{$name_japanese} = $name_english;
}
close(FH);

# Read input directory of script files.
opendir(DIR, $script_input_folder);
my @script_files = grep !/^\.\.?$/, readdir(DIR);
@script_files = sort { no warnings; $a <=> $b || $a cmp $b } @script_files;
closedir(DIR);

# Iterate through each script file, processing it into a spreadsheet.
for(my $i = 0; $i < scalar(@script_files); $i ++)
{
	# Create empty "script_entries" array.
	my @script_entries = ();

	# Store filename for spreadsheet.
	(my $spreadsheet_filename = $script_files[$i]) =~ s/\.txt/\.xls/g;

	# Status message.
	print "====================================================\n";
	print "[" . $script_files[$i] . "]\n\n";
	print "Extracting contents...\n\n";

	# Open script file for processing.
	open(FH, '<', $script_input_folder . $script_files[$i]) or die $!;
	while(<FH>)
	{
		# Remove carriage returns.
		$_ =~ s/\r\n//g;

		# Copy original script entry for Shift-JIS length calculation later on.
		my $text_original = $_;

		# Encode script entry from Shift-JIS to UTF-8.
		$_ = Encode::encode("utf-8", Encode::decode("shiftjis", $_));

		# Skip empty lines.
		next if /^\s*$/;

		# Store script entry's offset in a new element of "script_entries" array.
		if($_ =~ /^Position:/)
		{
			$_ =~ s/Position: //g;
			push(@script_entries, hex($_));
		}
		# Append script entry itself to last element of "script_entries" array, along with its length in bytes.
		else
		{
			$script_entries[scalar(@script_entries) - 1] .= "|" . $_ . "|" . (ShiftJIS::String::length($text_original) * 2);
		}
	}
	close(FH);

	# Print each script entry, along with its offset and length in bytes.
	for(my $j = 0; $j < scalar(@script_entries); $j ++)
	{
		# Isolate current string.
		my $string_current = (split /\|/, $script_entries[$j])[1];
		my $string_current_hex = ascii_to_hex(Encode::encode("shiftjis", Encode::decode("utf-8", $string_current)));
		my $string_previous;
		my $string_previous_hex;
		my $string_next;
		my $string_next_hex;

		# Setup group flags.
		my $group_start = 0;
		my $group_end = 0;

		# Isolate previous string.
		if($j > 0)
		{
			$string_previous = (split /\|/, $script_entries[$j - 1])[1];
			$string_previous_hex = ascii_to_hex(Encode::encode("shiftjis", Encode::decode("utf-8", $string_previous)));
		}

		# Isolate next string.
		if($j < scalar(@script_entries) - 1)
		{
			$string_next = (split /\|/, $script_entries[$j + 1])[1];
			$string_next_hex = ascii_to_hex(Encode::encode("shiftjis", Encode::decode("utf-8", $string_next)));
		}

		# String is beginning of a dialogue entry.
		if($string_previous_hex =~ /8146$/ && $string_current_hex =~ /^(8140|8175)/)
		{
			$group_start = 1;
		}

		# String is end of a dialogue entry.
		if(($string_next_hex =~ /8146$/ || $string_next_hex !~ /^(8140|8175)/ || $j == scalar(@script_entries) - 1)
			&& $string_current_hex =~ /^(8140|8175)/)
		{
			$group_end = 1;
		}

		# String is a standalone dialogue entry.
		if($group_start == 1 && $group_end == 1)
		{
			$script_entries[$j] .= "|X";
		}
		# String is the first dialogue entry of multiple.
		elsif($group_start == 1 && $group_end == 0)
		{
			$script_entries[$j] .= "|1";
		}
		# String is part of multiple dialogue entries, but not the first.
		elsif($group_start == 0 && $string_current_hex =~ /^(8140|8175)/ && ($string_previous_hex =~ /8146$/ || $string_previous_hex =~ /^(8140|8175)/))
		{
			$script_entries[$j] .= "|" . ((split /\|/, $script_entries[$j - 1])[3] + 1);
		}
		# String is part of a one-off message (e.g., save/load prompt).
		elsif($group_start == 0 && $string_current_hex =~ /^(8140|8175)/ && $string_previous_hex !~ /8146$/ && $string_previous_hex !~ /^(8140|8175)/)
		{
			$script_entries[$j] .= "|X";
		}
		# String is a speaker's name.
		elsif($string_current_hex =~ /8146$/)
		{
			$script_entries[$j] .= "|N";
		}
		# String is a menu entry or label.
		else
		{
			$script_entries[$j] .= "|M";
		}
	}

	# Create spreadsheet.
	my $workbook = Spreadsheet::WriteExcel->new($spreadsheet_output_folder . $spreadsheet_filename);
	my $worksheet = $workbook->add_worksheet();
	
	# Define spreadsheet header row.
	my $header_bg_color = $workbook->set_custom_color(40, 191, 191, 191);
	my $header_format = $workbook->add_format();
	$header_format->set_bold();
	$header_format->set_border();
	$header_format->set_bg_color(40);

	# Define spreadsheet formatting.
	my $cell_format = $workbook->add_format();
	$cell_format->set_border();
	$cell_format->set_align('left');
	$cell_format->set_text_wrap();

	# Define spreadsheet column widths.
	$worksheet->set_column('A:A', 7);
	$worksheet->set_column('B:B', 7);
	$worksheet->set_column('C:C', 7);
	$worksheet->set_column('D:D', 55);
	$worksheet->set_column('E:E', 55);
	$worksheet->set_column('F:F', 30);
	$worksheet->set_column('G:G', 55);

	# Define spreadsheet header row's labels.
	$worksheet->write(0, 0, "Offset", $header_format);
	$worksheet->write(0, 1, "Bytes", $header_format);
	$worksheet->write(0, 2, "Type", $header_format);
	$worksheet->write(0, 3, "Japanese Original", $header_format);
	$worksheet->write(0, 4, "English Translation", $header_format);
	$worksheet->write(0, 5, "Notes", $header_format);
	$worksheet->write(0, 6, "Machine Translation", $header_format);

	# Iterate through each script entry 
	for(my $j = 0; $j < scalar(@script_entries); $j ++)
	{
		# Extract each script entry element.
		my @elements = split /\|/, $script_entries[$j];

		# Store each property in separate variable.
		my $script_entry_offset = $elements[0];
		my $script_entry_byte_length = $elements[2];
		my $script_entry_type = $elements[3];
		my $script_entry_japanese_text = $elements[1];

		# Status message.
		print $script_entry_offset . "|" . $script_entry_byte_length . "|" . $script_entry_type . "|" . $script_entry_japanese_text . "\n";

		# Write each element to a column in current spreadsheet row.
		$worksheet->write($j + 1, 0, $script_entry_offset, $cell_format);
		$worksheet->write($j + 1, 1, $script_entry_byte_length, $cell_format);
		$worksheet->write($j + 1, 2, $script_entry_type, $cell_format);
		$worksheet->write_utf16be_string($j + 1, 3, Encode::encode("utf-16", Encode::decode("utf-8", $script_entry_japanese_text)), $cell_format);
		$worksheet->write($j + 1, 5, "", $cell_format);

		# If entry is a name, pre-populate translation.
		if($script_entry_type eq "N" && exists $names{$script_entry_japanese_text})
		{
			$worksheet->write($j + 1, 4, $names{$script_entry_japanese_text}, $cell_format);
			$worksheet->write($j + 1, 6, $names{$script_entry_japanese_text}, $cell_format);
		}
		# Otherwise, write empty cell.
		else
		{
			$worksheet->write($j + 1, 4, "", $cell_format);
			$worksheet->write($j + 1, 6, "", $cell_format);
		}

		# Add machine translation for entries (dialogue or menus).
		if($script_entry_type eq "X" || $script_entry_type eq "M")
		{
			# Store and clean Japanese text.
			my $japanese_text = Encode::decode("utf-8", $script_entry_japanese_text);
			$japanese_text =~ s/^\s+|\s+$//g;

			# Make DeepL API call, retrieving English translation.
			my $http = HTTP::Tiny->new;
			my $post_data = uri_encode("auth_key=" . $deepl_api_key . "&target_lang=EN-US&source_lang=JA&text=" . $japanese_text);
			my $response = $http->get("https://api-free.deepl.com/v2/translate?" . $post_data);
			my $english_translation = decode_json($response->{'content'})->{'translations'}->[0]->{'text'};

			# Write machine translation to spreadsheet.
			$worksheet->write($j + 1, 6, $english_translation, $cell_format);
		}
		# Add machine translation for grouped dialogue entries.
		elsif($script_entry_type eq "1")
		{
			# Store and clean Japanese text.
			my $japanese_text = Encode::decode("utf-8", $script_entry_japanese_text);
			$japanese_text =~ s/^\s+|\s+$//g;

			# Set end-of-group boolean.
			my $group_end = 0;

			# Set "k" to next script entry element (i.e., j + 1).
			my $k = $j + 1;
			
			# Seek next dialogue entry until group is complete.
			while($group_end == 0 && $k < scalar(@script_entries) - 1)
			{
				# Extract next script entry element.
				my @elements_next = split /\|/, $script_entries[$k];

				# Store Japanese text.
				my $script_entry_next_japanese_text = Encode::decode("utf-8", $elements_next[1]);
				$script_entry_next_japanese_text =~ s/^\s+|\s+$//g;

				# Append Japanese text.
				$japanese_text .= $script_entry_next_japanese_text;

				# Increase "k" by one to seek next script entry.
				$k ++;

				# Store type of next script entry.
				@elements_next = split /\|/, $script_entries[$k];
				my $script_entry_next_type = $elements_next[3];

				# Next script entry is not part of group, so end loop.
				if($script_entry_next_type !~ /^\d+$/)
				{
					$group_end = 1;
				}
			}

			# Make DeepL API call, retrieving English translation.
			my $http = HTTP::Tiny->new;
			my $post_data = uri_encode("auth_key=" . $deepl_api_key . "&target_lang=EN-US&source_lang=JA&text=" . $japanese_text);
			my $response = $http->get("https://api-free.deepl.com/v2/translate?" . $post_data);
			my $english_translation = decode_json($response->{'content'})->{'translations'}->[0]->{'text'};

			# Write machine translation to spreadsheet.
			$worksheet->write($j + 1, 6, $english_translation, $cell_format);
		}
	}

	# Close spreadsheet.
	$workbook->close();

	# Status message.
	print "\nWrote spreadsheet \"" . $spreadsheet_filename . "\".\n";
}

# Status message.
print "====================================================\n";