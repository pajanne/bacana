#!/bin/bash

usage() {
cat <<OPTIONS
Usage: merge_sequence.sh -n COMMON_NAME -f FASTA_FILE -m MERGED_FASTA_FILE

Options:

 -n COMMON_NAME     
    Unique common NAME 
    e.g. Ashahii_WAL8301

 -f FASTA_FILE     
    Path to the fasta FILE 
    e.g. /nfs/pathogen/metahit/refs/Alistipez/shahii_WAL8301/improved/Alistipez_shahii_WAL8301.fasta

 -m MERGED_FASTA_FILE
    Path to the new merged fasta FILE
    e.g. /lustre/scratch101/sanger/ap12/ann_pipeline/Ashahii_WAL8301_merged.fasta

OPTIONS
}

ERR_OPT=85 # Command-line exit error
NO_ARGS=0 

#
# Command-line arguments and script usage
#
if [ $# -eq "$NO_ARGS" ]
then 
  usage
  exit $ERR_OPT # Exit and explain usage. Usage: scriptname -options 
fi

print $OPTARG
while getopts "n:f:m:" Option 
do 
    case $Option in 
	n ) COMMON_NAME=$OPTARG;;
	f ) FASTA_FILE=$OPTARG;;
	m ) MERGED_FASTA_FILE=$OPTARG;;
        * ) echo "Unimplemented option chosen."
            usage
            exit;;
    esac 
done 

if [[ -z $COMMON_NAME ]] || [[ -z $FASTA_FILE ]] || [[ -z $MERGED_FASTA_FILE ]]
then
    echo "You must supply a common name (-n), fasta file (-f) and merged fasta file (-m) parameters."
    usage
    exit 1
fi

UNION=/software/pathogen/external/applications/EMBOSS-6.3.1-no-postgres/bin/union
DESCSEQ=/software/pathogen/external/applications/EMBOSS-6.3.1-no-postgres/bin/descseq

$UNION -sequence $FASTA_FILE -stdout Yes -auto Yes | $DESCSEQ -filter Yes -name $COMMON_NAME -auto Yes -outseq $MERGED_FASTA_FILE