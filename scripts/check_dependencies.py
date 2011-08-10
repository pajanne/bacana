'''
Created on Aug 09, 2011
by
@author: Anne Pajon (ap12)
Copyright (c) 2011 Wellcome Trust Sanger Institute. All rights reserved.
'''

from optparse import OptionParser
import sys, os
import subprocess

### ---------------------------------------------------------------------------
DEPENDENCIES = {
    # GeneFinding
    'emboss_seqret_exec'   : '/software/pathogen/external/applications/EMBOSS-6.3.1-no-postgres/bin/seqret',
    'emboss_union_exec'    : '/software/pathogen/external/applications/EMBOSS-6.3.1-no-postgres/bin/union',
    'emboss_descseq_exec'  : '/software/pathogen/external/applications/EMBOSS-6.3.1-no-postgres/bin/descseq',

    'splitter_exec'        : '/nfs/users/nfs_a/ap12/genlibpy/genepy/convertors/splitter_wrapper.py',

    'glimmer3_exec'        : '/software/pathogen/external/applications/glimmer/glimmer/scripts/g3-iterated.csh',
    'glimmer2tab_exec'     : '/nfs/users/nfs_a/ap12/genlibpy/genepy/convertors/glimmer2tab.py',

    'prodigal_exec'        : '/software/pathogen/external/bin/prodigal',
    'prodigal2tab_exec'    : '/nfs/users/nfs_a/ap12/genlibpy/genepy/convertors/prodigal2tab.py',

    'trnascan_exec'        : '/software/pathogen/external/bin/tRNAscan-SE',
    'trnascan2tab_exec'    : '/nfs/users/nfs_a/ap12/genlibpy/genepy/convertors/trnascan2tab.py',

    'rfamscan_exec'        : '/software/pathogen/psu_svn/trunk/genexec/perl/src/rfam_scan.pl',
    'cm_file'              : '/lustre/scratch101/blastdb/Rfam/Rfam_9.1/Rfam.cm',
    'rfamscan2tab_exec'    : '/software/pathogen/psu_svn/trunk/genexec/perl/src/rfamscan2tab.pl',

    'blastall_exec'        : '/software/bin/blastall',
    'blastx_opts'          : '/data/blastdb/uniprot',
    'blast2tab_exec'       : '/software/pathogen/psu_svn/trunk/genexec/perl/src/blast_formatter.pl',

    'repeatscout_bin'      : '/software/pathogen/external/applications/repeatscout/RepeatScout-1/',
    'repeatmasker_exec'    : '/software/pubseq/bin/RepeatMasker',
    'repeat2tab_exec'      : '/nfs/users/nfs_a/ap12/genlibpy/genepy/convertors/repeat2tab.py',

    'alienhunter_exec'     : '/nfs/users/nfs_a/ap12/lib/alien_hunter/alien_hunter',

    'rnammer_exec'         : '/nfs/users/nfs_a/ap12/lib/rnammer-1.2/rnammer',
    'rnammer2tab_exec'     : '/nfs/users/nfs_a/ap12/genlibpy/genepy/convertors/rnammer2tab.py',

    'merger_exec'          : '/nfs/users/nfs_a/ap12/genlibpy/genepy/pathtrack/gfind_merger.py',

    # GeneFunction
    'emboss_extractfeat_exec' : '/software/pathogen/external/applications/EMBOSS-6.3.1-no-postgres/bin/extractfeat',
    'emboss_transeq_exec'  : '/software/pathogen/external/applications/EMBOSS-6.3.1-no-postgres/bin/transeq',

    'extractfeat_exec'     : '/nfs/users/nfs_a/ap12/genlibpy/genepy/convertors/extractfeat_wrapper.py',

    'iprscan_exec'         : '/software/iprscan/bin/iprscan',
    'iprscan2embl_exec'    : '/nfs/users/nfs_a/ap12/genlibpy/genepy/convertors/iprscan2embl.py',

    'blastall_exec'        : '/software/bin/blastall',
    'blastp_opts'          : '/data/blastdb/uniprot',
    'blast2tab_exec'       : '/software/pathogen/psu_svn/trunk/genexec/perl/src/blast_formatter.pl',

    'tmhmm_exec'           : '/software/pathogen/external/applications/TMHMM/TMHMM2.0c/bin/tmhmm',
    'tmhmm2embl_exec'      : '/nfs/users/nfs_a/ap12/genlibpy/genepy/convertors/tmhmm2embl.py',

    'signalp_exec'         : '/software/pathogen/external/applications/signalp/signalp//signalp',

    'pfamscan_exec'        : '/software/pathogen/external/applications/pfam_scan/bin/pfam_scan.pl',
    'pfam_dir'             : '/data/blastdb',
    'pfam2embl_exec'       : '/nfs/users/nfs_a/ap12/genlibpy/genepy/convertors/pfam2embl.py',
    'pfam2go'              : '/nfs/users/nfs_a/ap12/lib/go/pfam2go',
    'go_map'               : '/nfs/users/nfs_a/ap12/lib/go/map'
    
    }

### ---------------------------------------------------------------------------
def isSoftInstalled(softname):
    """
    Return true if a given software is installed, false otherwise
    """
    retval = subprocess.call(['which %s' % softname], shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if retval == 0:
        return True
    else:
        return False

### ---------------------------------------------------------------------------
def main():
    print "Checking dependencies..."
    not_found = 0
    for softname, location in DEPENDENCIES.iteritems():
        if not os.path.exists(location):
            print "not found: %s! Please check your setup environment." % location
            not_found += 1
        else:
            print "found: %s" % location
    if not_found > 0:
        print "%s dependencies not found" % not_found
    else:
        print "all dependencies installed"

### ---------------------------------------------------------------------------
if __name__ == '__main__':
    main()
        
