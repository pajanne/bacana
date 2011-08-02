#!/bin/sh

### ----------------------------------------------------------------------------
### Set up environment for pathpipe for running the annotation pipeline
### ap12@sanger.ac.uk
### ----------------------------------------------------------------------------

# Clean environment variables
export PERL5LIB=

# Source main environment setup
source /software/pathogen/internal/pathdev/bin/setup_pathpipe_environment.sh

# Set up python environment
export PYTHONPATH=/nfs/users/nfs_a/ap12/lib/gdata-2.0.10/lib/python:/nfs/users/nfs_a/ap12/genlibpy:/software/pathogen/external/lib/python2.6/site-packages/:/software/pathogen/psu_svn/trunk/genlib/python

# Proxy setting for gdata python api
export http_proxy="http://wwwcache.sanger.ac.uk:3128"
export https_proxy="https://wwwcache.sanger.ac.uk:3128"

# VR codebase
export VR_CODEBASE=/nfs/users/nfs_a/ap12/git/vr-codebase

# Pathogens Annotation Pipeline
export ANN_PIPELINE=/nfs/users/nfs_a/ap12/git/ann-pipeline

# Set up perl environment
export PERL5LIB=/software/vertres/lib/all:$VR_CODEBASE/modules:$ANN_PIPELINE/modules:$VR_CODEBASE/scripts:/software/pathogen/internal/pathdev/lib:/software/pathogen/internal/prod/lib:/software/pathogen/internal/preprod/lib:/software/pathogen/external/apps/var/lib:/software/pathogen/external/apps/lib:/software/pathogen/external/apps/usr/local/lib:/software/pathogen/external/apps/usr/lib



