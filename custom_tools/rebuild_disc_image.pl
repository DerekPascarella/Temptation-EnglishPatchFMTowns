#!/usr/bin/perl
#
# rebuild_disc_image.pl
# Rebuild disc image for the game "Yuuwaku" (Temptation) using CD-REPLACE
# (https://www.romhacking.net/utilities/852/).
#
# Written by Derek Pascarella (ateam)

# Include necessary modules.
use strict;

# Define paths.
my $disc_image_extracted_folder = "Z:\\fm_towns\\disc_images\\Yuuwaku\\disc_image_extracted_new\\";
my $disc_image = "Z:\\fm_towns\\disc_images\\Yuuwaku\\disc_image_new\\Temptation (T-En v0.91).bin";

# Store list of files to replace.
my @file_list = ("N_BBAR_7.BIN",
				 "N_BBAR_8.BIN",
				 "N_BDAI_6.BIN",
				 "N_BUNNY5.BIN",
				 "N_BUNNY8.BIN",
				 "N_CITY_1.BIN",
				 "N_CITY_4.BIN",
				 "N_CLUB_0.BIN",
				 "N_CLUB_1.BIN",
				 "N_CLUB_2.BIN",
				 "N_ED1_1.BIN",
				 "N_ETC_2.BIN",
				 "N_ETC_3.BIN",
				 "N_ETC_4.BIN",
				 "N_ETC_6.BIN",
				 "N_ETC_7.BIN",
				 "N_ETC_8.BIN",
				 "N_ETC_A.BIN",
				 "N_EX1_1.BIN",
				 "N_EX1_2.BIN",
				 "N_EX1_3.BIN",
				 "N_EX1_5.BIN",
				 "N_EX1_6.BIN",
				 "N_EX1_7.BIN",
				 "N_EX1_9.BIN",
				 "N_GAME_1.BIN",
				 "N_GAME_3.BIN",
				 "N_GAME_6.BIN",
				 "N_HOTE_1.BIN",
				 "N_HOTE_4.BIN",
				 "N_HOTE_A.BIN",
				 "N_JIMU_0.BIN",
				 "N_JIMU_1.BIN",
				 "N_JIMU_2.BIN",
				 "N_JIMU_3.BIN",
				 "N_JIMU_4.BIN",
				 "N_JIMU_5.BIN",
				 "N_JIMU_6.BIN",
				 "N_JIMU_7.BIN",
				 "N_KOEN_1.BIN",
				 "N_KOEN_2.BIN",
				 "N_LOAD_.BIN",
				 "N_NOMI_1.BIN",
				 "N_OPEN_1.BIN",
				 "N_OPEN_2.BIN",
				 "N_OPEN_.BIN",
				 "N_POLI_1.BIN",
				 "N_YASI_A.BIN",
				 "N_YASI_B.BIN");

# Iterate through each element of file list array.
foreach(@file_list)
{
	# Construct full path to replacement file.
	my $file_path = $disc_image_extracted_folder . "\\" . $_;

	# Invoke CD-REPLACE.
	system "cd-replace.exe \"$disc_image\" $_ \"$file_path\"";
}