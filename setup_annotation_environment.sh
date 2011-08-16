#!/bin/sh

### ----------------------------------------------------------------------------
### Set up environment for pathpipe for running the annotation pipeline
### ap12@sanger.ac.uk
### ----------------------------------------------------------------------------

# VR codebase
#export VR_CODEBASE=/nfs/users/nfs_a/ap12/git/vr-codebase
export VR_CODEBASE=/software/pathogen/internal/pathdev/vr-codebase/

# Pathogens Annotation Pipeline
export ANN_PIPELINE=/nfs/users/nfs_a/ap12/git/ann-pipeline

### ----------------------------------------------------------------------------
# Set up environment to use LSF
export LSB_DEFAULTPROJECT="team81"
export LSF_ENVDIR=/etc
export LSF_BINDIR=/usr/local/lsf/7.0/linux2.6-glibc2.3-x86_64/bin
export LSF_LIBDIR=/usr/local/lsf/7.0/linux2.6-glibc2.3-x86_64/lib
export LSF_SERVERDIR=/usr/local/lsf/7.0/linux2.6-glibc2.3-x86_64/etc
export XLSF_UIDDIR=/usr/local/lsf/7.0/linux2.6-glibc2.3-x86_64/lib/uid
export LD_LIBRARY_PATH=/usr/local/lsf/7.0/linux2.6-glibc2.3-x86_64/lib:$LD_LIBRARY_PATH

### ----------------------------------------------------------------------------
# Set up python environment
export PYTHONPATH=/nfs/users/nfs_a/ap12/lib/gdata-2.0.10/lib/python
export PYTHONPATH=$PYTHONPATH:/nfs/users/nfs_a/ap12/genlibpy
export PYTHONPATH=$PYTHONPATH:/software/pathogen/external/lib/python2.6/site-packages/
export PYTHONPATH=$PYTHONPATH:/software/pathogen/psu_svn/trunk/genlib/python

# Proxy setting for gdata python api
export http_proxy="http://wwwcache.sanger.ac.uk:3128"
export https_proxy="https://wwwcache.sanger.ac.uk:3128"

### ----------------------------------------------------------------------------
# Set up perl environment
export PERL_INLINE_DIRECTORY=/nfs/users/nfs_p/pathpipe/_Inline
export PERL5LIB=/software/vertres/lib/all
export PERL5LIB=$PERL5LIB:$VR_CODEBASE/modules
export PERL5LIB=$PERL5LIB:$ANN_PIPELINE/modules
export PERL5LIB=$PERL5LIB:/software/pathogen/internal/pathdev/lib
export PERL5LIB=$PERL5LIB:/software/pathogen/internal/prod/lib
export PERL5LIB=$PERL5LIB:/software/pathogen/internal/preprod/lib
export PERL5LIB=$PERL5LIB:/software/pathogen/external/apps/var/lib
export PERL5LIB=$PERL5LIB:/software/pathogen/external/apps/lib
export PERL5LIB=$PERL5LIB:/software/pathogen/external/apps/usr/local/lib
export PERL5LIB=$PERL5LIB:/software/pathogen/external/apps/usr/lib
export PERL5LIB=$PERL5LIB:/software/pathogen/lib/lib/site_perl/5.8.8/x86_64-linux-thread-multi
export PERL5LIB=$PERL5LIB:/software/pathogen/lib/lib/site_perl/5.8.8
export PERLDOC_PAGER=less

### ----------------------------------------------------------------------------
# Set up PATH
export PATH=/software/bin
export PATH=$PATH:/bin
export PATH=$PATH:/usr/bin
export PATH=$PATH:$LSF_SERVERDIR
export PATH=$PATH:$LSF_BINDIR
export PATH=$PATH:$VR_CODEBASE/scripts
export PATH=$PATH:/software/pathogen/internal/pathdev/bin
export PATH=$PATH:/software/pathogen/internal/prod/bin
export PATH=$PATH:/software/pathogen/internal/preprod/bin
export PATH=$PATH:/software/pathogen/external/apps/bin
export PATH=$PATH:/software/pathogen/external/apps/usr/bin
export PATH=$PATH:/software/pathogen/external/apps/usr/local/bin
export PATH=$PATH:/software/pathogen/external/apps/usr/local/sbin
export PATH=$PATH:/software/pathogen/external/apps/sbin
export PATH=$PATH:/software/vertres/bin-external/
# For annotation pipeline
export PATH=$PATH:$ANN_PIPELINE/scripts
export PATH=$PATH:/software/pathogen/external/applications/glimmer/glimmer/scripts/ # g3-iterated.csh 
export PATH=$PATH:/software/pathogen/external/bin/ # prodigal
export PATH=$PATH:/nfs/users/nfs_a/ap12/lib/rnammer-1.2/ # rnammer
export PATH=$PATH:/software/pubseq/bin/ # RepeatMasker
export PATH=$PATH:/nfs/users/nfs_a/ap12/lib/alien_hunter/ # alien_hunter
### ----------------------------------------------------------------------------

