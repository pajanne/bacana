#!/bin/bash

usage() {
cat <<OPTIONS
Usage: run_annotation_pipeline.sh -d DEST_DIR -n COMMON_NAME -f FASTA_FILE

Options:

 -d DEST_DIR  
    Directory where the output of the pipeline will be written to
    e.g. /lustre/scratch101/sanger/ap12/ann_pipeline/

 -n COMMON_NAME     
    Unique common NAME 
    e.g. Ashahii_WAL8301

 -f FASTA_FILE     
    Path to the fasta FILE 
    e.g. /nfs/pathogen/metahit/refs/Alistipez/shahii_WAL8301/improved/Alistipez_shahii_WAL8301.fasta

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
while getopts "d:n:f:" Option 
do 
    case $Option in 
        d ) DEST_DIR=$OPTARG;;
	n ) COMMON_NAME=$OPTARG;;
	f ) FASTA_FILE=$OPTARG;;
        * ) echo "Unimplemented option chosen."
            usage
            exit;;
    esac 
done 

if [[ -z $DEST_DIR ]] || [[ -z $COMMON_NAME ]] || [[ -z $FASTA_FILE ]]
then
    usage
    exit 1
fi

#
# setting output directory
#
echo "Setting output directory $DEST_DIR"
if [ ! -d $DEST_DIR ]
then
    echo "Creating directory $DEST_DIR"
    mkdir -p $DEST_DIR
fi

# 
# checking script directory
#
SCRIPT_DIR=`dirname $(readlink -f $0)`
cd $SCRIPT_DIR
echo "Executing script at $SCRIPT_DIR"

#
# sourcing setup environment
#
SETUP_SCRIPT='../setup_annotation_environment.sh'
source $SETUP_SCRIPT
echo "Sourced setup environment $SETUP_SCRIPT"

#
# checking dependencies
#
check_dependencies.py

#
# checking fasta file
#
if  [ ! -f $FASTA_FILE ] 
then
    echo "The file $FASTA_FILE does not exist."
    echo "Please provide full path to the file."
    exit
fi

NB_RECORD=`more $FASTA_FILE | grep '>' | wc -l`
if [ $NB_RECORD > 1 ]
then
    echo "More than one record in $FASTA_FILE"
    echo "$NB_RECORD records found, please merge sequence before running the pipeline again."
    exit
fi

#
# copying fasta file to lustre
#
echo "Copying $FASTA_FILE to $DEST_DIR"
rsync -aPv $FASTA_FILE $DEST_DIR/$COMMON_NAME.fasta

#
# generating config files
#
CONF_FILE="annotation_pipeline.conf"
if [ -f $DEST_DIR/$CONF_FILE ]
then
    echo "Removing existing configuration file $CONF_FILE"
    rm -f $DEST_DIR/$CONF_FILE
fi
generate_config_file.py -n $COMMON_NAME -f $DEST_DIR/$COMMON_NAME.fasta -r $DEST_DIR -c $CONF_FILE

#
# running the pipeline
#
echo "Running the pipeline..."
run-pipeline -c $DEST_DIR/$CONF_FILE -m 10000 -v -s 1