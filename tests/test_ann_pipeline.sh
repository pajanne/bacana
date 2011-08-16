#!/bin/bash

usage() {
cat <<OPTIONS
Usage: build.sh -d TEST_DIR

Options:

 -d TEST_DIR  
    Directory where the output of the test pipeline will be written to
    e.g. /lustre/scratch101/sanger/ap12/test_ann_pipeline/

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
while getopts "d:" Option 
do 
    case $Option in 
        d ) TEST_DIR=$OPTARG;;
        * ) echo "Unimplemented option chosen."
            usage
            exit;;
    esac 
done 

if [[ -z $TEST_DIR ]] 
then
    echo "You must supply a output test directory (-d)."
    usage
    exit 1
fi

#
# setting test directory
#
echo "Setting output test directory $TEST_DIR"
if [[ -f $TEST_DIR ]]
then
    echo "Creating test directory $TEST_DIR"
    mkdir $TEST_DIR
fi

# 
# checking script directory
#
SCRIPT_DIR=`dirname $(readlink -f $0)`
DATA_DIR=`dirname $(readlink -f "${SCRIPT_DIR}/")`
cd $SCRIPT_DIR
echo "Executing test script at $SCRIPT_DIR"

#
# sourcing setup environment
#
SETUP_SCRIPT='../setup_annotation_environment.sh'
source $SETUP_SCRIPT
echo "Sourced setup environment $SETUP_SCRIPT"

#
# checking dependencies
#
../scripts/check_dependencies.py

#
# generating config files
#
CONF_FILE="annotation_pipeline.conf"
if [[ -f $TEST_DIR/$CONF_FILE ]]
then
    echo "Removing existing configuration file $CONF_FILE"
    rm -f $TEST_DIR/$CONF_FILE
fi
../scripts/generate_config_file.py -n test -f  $DATA_DIR/data/sequence.fna -r $TEST_DIR -c $CONF_FILE

#
# running the pipeline
#
echo "Running the pipeline..."
run-pipeline -c $TEST_DIR/$CONF_FILE -m 10000 -v -s 1