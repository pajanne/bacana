#!/bin/bash

# 
# checking directories
#
SCRIPT_DIR=`dirname $(readlink -f $0)`
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
python ../scripts/check_dependencies.py

#
# generating config files
#
python ../scripts/generate_config_file.py -n test -f  $SCRIPT_DIR/../data/Scaffolds.fna -r /lustre/scratch101/sanger/ap12/test_ann_pipeline/

#
# running the pipeline
#
echo "Running the pipeline..."
run-pipeline -c /lustre/scratch101/sanger/ap12/test_ann_pipeline/annotation_pipeline.conf -m 10000 -v -s 1