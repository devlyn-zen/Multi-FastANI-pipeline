#!/bin/bash

# To set up the Conda
source /opt/bifxapps/miniconda3/etc/profile.d/conda.sh
unset $PYTHONPATH
unset $PERL5LIB

# First, input the table file contafile path of all the target genomes
Sample_table="/mnt/bigdata/linuxhome/dzeng24/multi-ANI/multi_sample.tsv"
# Second, input the file path of the reference list of genome to be compared
Ref_List="/mnt/bigdata/linuxhome/dzeng24/practice/y_1000_sample.txt"
# Third, input a output directory with full path
OUTPUT_DIR="/mnt/bigdata/linuxhome/dzeng24/multi-ANI/trial_3"

# Read the samples table line by line
{
	read  # Skip the header line
	while IFS=$'\t' read -r Strain R1 R2; do
		# Skip if any of the fields are empty
		if [[ -z "$R1" || -z "$R2" ]]; then
			continue
		fi

		# Extract base names of R1 and R2
		BASE_R1=$(basename "$R1" .fastq)
		BASE_R2=$(basename "$R2" .fastq)
		SHARED_BASE="${BASE_R1%_R1*}"

		# Define dynamically named output files
		TRIM_R1="${OUTPUT_DIR}/${BASE_R1}_pairedtrimAd.fastq"
		TRIM_R2="${OUTPUT_DIR}/${BASE_R2}_pairedtrimAd.fastq"
		TRIM_UNPAIRED_R1="${OUTPUT_DIR}/${BASE_R1}_unpairedtrimAd_R1.fastq"
		TRIM_UNPAIRED_R2="${OUTPUT_DIR}/${BASE_R2}_unpairedtrimAd_R2.fastq"
		CONTIGS="${OUTPUT_DIR}/contigs_${SHARED_BASE}.fasta"
		FILTERED_CONTIGS="${OUTPUT_DIR}/filtered_contigs_${SHARED_BASE}.fasta"
		ANI_OUTPUT="${OUTPUT_DIR}/ANIresult_${SHARED_BASE}.txt"

		echo "Processing sample: $Strain ($SHARED_BASE)"

		# Step 1: Run Trimmomatic
		conda activate /mnt/bigdata/linuxhome/dzeng24/.conda/envs/sequence_analysis/
		/mnt/bigdata/linuxhome/dzeng24/.conda/envs/sequence_analysis/bin/trimmomatic PE -phred33 "$R1" "$R2" \
			"$TRIM_R1" "$TRIM_UNPAIRED_R1" "$TRIM_R2" "$TRIM_UNPAIRED_R2" \
			ILLUMINACLIP:TruSeq3-PE.fa:2:30:10 LEADING:3 TRAILING:3 SLIDINGWINDOW:3:30 MINLEN:36
		conda deactivate

		# Step 2: Run SPAdes
		conda activate /mnt/bigdata/linuxhome/dzeng24/.conda/envs/spades_env/
		python3 /mnt/bigdata/linuxhome/dzeng24/.conda/envs/spades_env/bin/spades.py -1 "$TRIM_R1" -2 "$TRIM_R2" -o "$OUTPUT_DIR/${SHARED_BASE}_spades"
		conda deactivate

		# Update the contigs file path after SPAdes output
		CONTIGS="$OUTPUT_DIR/${SHARED_BASE}_spades/contigs.fasta"

		# Step 3: Filter contigs
		conda activate /mnt/bigdata/linuxhome/dzeng24/.conda/envs/sequence_analysis/
		/mnt/bigdata/linuxhome/dzeng24/.conda/envs/sequence_analysis/bin/seqtk seq -L 2000 "$CONTIGS" > "$FILTERED_CONTIGS"
		conda deactivate

		# Step 4: Run FastANI
		conda activate /mnt/bigdata/linuxhome/dzeng24/.conda/envs/fastani_env/
		/mnt/bigdata/linuxhome/dzeng24/.conda/envs/fastani_env/bin/fastANI --query "$FILTERED_CONTIGS" --refList "$Ref_List" --output "$ANI_OUTPUT"
		conda deactivate

		echo "Sample $Strain complete. Result saved as $ANI_OUTPUT"

	done
} < "$Sample_table"

echo "All samples processed. Results are stored in $OUTPUT_DIR."