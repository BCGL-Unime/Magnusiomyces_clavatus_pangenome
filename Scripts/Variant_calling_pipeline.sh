#!/usr/bin/env bash

###############################
###   HELP FUNCTION
###############################
show_help() {
cat << EOF
Usage: $0 [OPTIONS]

Required arguments:
  -1 <file>          Read 1 (FASTQ.gz)
  -2 <file>          Read 2 (FASTQ.gz)
  -s <string>        Sample name
  -g <file>          Pangenome GBZ
  -m <file>          Pangenome MIN
  -d <file>          Pangenome DIST
  -z <file>          Pangenome ZIPcodes
  -r <file>          Reference assembly (FASTA)
  -t <int>           Number of threads

Optional:
  -h                 Show this help message and exit

Example:
  $0 -1 R1.fq.gz -2 R2.fq.gz -s SAMPLE \\
     -g graph.gbz -m graph.min -d graph.dist -z graph.zipcodes \\
     -r reference.fa -t 24

EOF
}

#############################################
###   PARSE ARGUMENTS
#############################################
while getopts ":1:2:s:g:m:d:z:r:t:h" opt; do
    case ${opt} in
        1 ) R1="$OPTARG" ;;
        2 ) R2="$OPTARG" ;;
        s ) SAMPLE="$OPTARG" ;;
        g ) GBZ="$OPTARG" ;;
        m ) MIN="$OPTARG" ;;
        d ) DIST="$OPTARG" ;;
        z ) ZIP="$OPTARG" ;;
        r ) REF="$OPTARG" ;;
        t ) threads="$OPTARG" ;;
        h ) show_help; exit 0 ;;
        \? ) echo "Invalid Option: -$OPTARG" >&2; exit 1 ;;
        : ) echo "Missing argument for -$OPTARG" >&2; exit 1 ;;
    esac
done

#############################################
###   CHECK REQUIRED ARGUMENTS
#############################################
if [[ -z "$R1" || -z "$R2" || -z "$SAMPLE" || -z "$GBZ" || -z "$MIN" || -z "$DIST" ||-z "$REF" || -z "$threads" ]]; then
    echo "Error: lacking one or more mandatory inputs."
    show_help
    exit 1
fi

#############################################
###   OUTPUT DIRECTORIES
#############################################
mkdir -p filt_gams vcf_freebayes bams

#############################################
### STEP 1 – vg giraffe (alignment)
#############################################
echo "### Aligning reads for sample $SAMPLE ###"

vg giraffe \
    -Z "$GBZ" -m "$MIN" -d "$DIST"  \
    -f "$R1" -f "$R2" \
    --read-group "$SAMPLE" \
    --sample "$SAMPLE" \
    -t "$threads" -A none \
    > "${SAMPLE}.gam"


#############################################
### STEP 2 – Filter GAM
#############################################
echo "### Filtering GAM for $SAMPLE ###"

vg filter \
    --min-primary 0.90 \
    --frac-score \
    --substitutions \
    --min-end-matches 1 \
    --min-mapq 20 \
    -t "$threads" \
    "${SAMPLE}.gam" \
    > "filt_gams/filt_${SAMPLE}.gam"

rm "${SAMPLE}.gam"

###################################################
### STEP 3 – Surject → BAM → Sort → Markdup
###################################################
echo "### Surjecting and processing BAM for $SAMPLE ###"

vg surject \
    --xg-name "$GBZ" \
    "filt_gams/filt_${SAMPLE}.gam" \
    -N "$SAMPLE" \
    -R "$SAMPLE" \
    --bam-output \
    -t "$threads" \
    | samtools sort -@ "$threads" -o tmp.bam -

echo "### Marking duplicates using sambamba ###"
sambamba markdup -t "$threads" \
    tmp.bam \
    bams/markdup_"$SAMPLE".bam

samtools index bams/markdup_"$SAMPLE".bam
rm tmp.bam

###################################################
### STEP 4 – Freebayes variant calling
###################################################
echo "### Calling variants with Freebayes ###"

if [[ ! -f "${REF}.fai" ]]; then
    echo "### Indexing reference assembly ###"
    samtools faidx "$REF"
fi

freebayes-parallel \
    <(fasta_generate_regions.py "${REF}.fai" 1000) "$threads" \
    -f "$REF" \
    bams/markdup_"$SAMPLE".bam \
    --ploidy 1 \
    > vcf_freebayes/raw_"$SAMPLE".vcf

vcftools \
    --vcf vcf_freebayes/raw_"$SAMPLE".vcf \
    --minDP 10 \
    --minQ 30 \
    --remove-indels \
    --non-ref-ac 1 \
    --recode --recode-INFO-all \
    --out vcf_freebayes/filt_"$SAMPLE"

bgzip vcf_freebayes/filt_"$SAMPLE".recode.vcf
tabix vcf_freebayes/filt_"$SAMPLE".recode.vcf.gz

echo "### PIPELINE COMPLETED for $SAMPLE ###"

#bcftools merge -0 filtTE_norm.vcf.gz concat_*.vcf.gz -o merged.vcf
#bcftools norm -m- -a merged.vcf -o norm.vcf

#bcftools view -T ^Magnusiomyces_clavatus.filteredRepeats.bed norm.vcf > filtTE_norm.vcf 
#vcftools --vcf filtTE_norm.vcf --recode --recode-INFO-all --maf 0.05