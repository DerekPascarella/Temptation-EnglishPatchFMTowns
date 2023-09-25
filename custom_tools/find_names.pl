#!/usr/bin/perl
#
# find_names.pl
# Generate list of all unique speaker names used in the game "Yuuwaku" (Temptation).
#
# Written by Derek Pascarella (ateam)

# Include necessary modules.
use strict;
use utf8;
use ShiftJIS::String;
use Encode qw(decode encode);
use String::HexConvert ':all';

# Create name hash.
my %names;

# Store input/output paths.
my $script_folder = "/mnt/z/fm_towns/disc_images/Yuuwaku/script/txt_original/";

# Read input directory of script files.
opendir(DIR, $script_folder);
my @script_files = grep !/^\.\.?$/, readdir(DIR);
@script_files = sort { no warnings; $a <=> $b || $a cmp $b } @script_files;
closedir(DIR);

# Iterate through each script file.
for(my $i = 0; $i < scalar(@script_files); $i ++)
{
	# Open script file for processing.
	open(FH, '<', $script_folder . $script_files[$i]) or die $!;
	while(<FH>)
	{
		# Skip empty lines and "Position" labels.
		next if /^\s*$/;
		next if /^Position/g;

		# Remove carriage returns.
		$_ =~ s/\r\n//g;

		# Line ends in a Shift-JIS-encoded colon and doesn't start with a space or bracket, and
		# so is a speaker's name.
		if(ascii_to_hex($_) =~ /8146$/ && ascii_to_hex($_) !~ /^(8140|8175)/)
		{
			# Store name.
			my $name = Encode::encode("utf-8", Encode::decode("shiftjis", $_));

			# Add it to hash if not already present.
			if(!exists $names{$name})
			{
				$names{$name} = $name;
			}
		}
	}
}

# Print each unique name found in script, the output of which can be redirected into a text file.
foreach my $name (keys %names)
{
	print $name . "\n";
}