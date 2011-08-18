#!/usr/bin/env python
'''
Created on Aug 09, 2011
by
@author: Anne Pajon (ap12)
Copyright (c) 2011 Wellcome Trust Sanger Institute. All rights reserved.
'''

from optparse import OptionParser
import sys, os

### ---------------------------------------------------------------------------

GFIND_TEMPLATE = """
root    => '%(root)s/%(common_name)s',
module  => 'Pathogens::Annotate::%(step)s',
prefix  => '_',
log	=> '%(root)s/log/%(common_name)s.log',

data => {
    fasta => '%(fasta_file)s',
    common_name => '%(common_name)s',
},

"""
GFIND_STEPS = ['Glimmer', 'Prodigal', 'Rnammer', 'Trnascan', 'RepeatScout', 'AlienHunter', 'PredictionResults']

GFUNC_TEMPLATE = """
root    => '%(root)s/%(common_name)s',
module  => 'Pathogens::Annotate::GeneFunction',
prefix  => '_',
log	=> '%(root)s/log/%(common_name)s.log',

data => {
    embl => '%(root)s/%(common_name)s/GFIND/sequence.embl',
    common_name => '%(common_name)s',
},

"""

### ---------------------------------------------------------------------------
def main():
    usage = "usage: %prog -n NAME -f FILE -r ROOT"
    parser = OptionParser(usage=usage)
    parser.add_option("-n", metavar="NAME", help="Unique common NAME (e.g. Bpseudomallei_K96243)", action="store", type="string", dest="name")
    parser.add_option("-f", metavar="FILE", help="Path to the fasta FILE (e.g. /lustre/scratch103/sanger/ap12/test_data/Burkholderia_pseudomallei_K96243.fna)", action="store", type="string", dest="file")
    parser.add_option("-r", metavar="ROOT", help="ROOT directory where the output of pipeline will be written to (e.g. /lustre/scratch101/sanger/ap12/ann_pipeline/)", action="store", type="string", dest="root")
    parser.add_option("-c", metavar="CONF", help="CONFiguration file name (e.g. annotation_pipeline.conf)", action="store", type="string", dest="conf")
    (options, args) = parser.parse_args()
    
    if not (options.root and options.name and options.file and options.conf):
        parser.print_help()
        sys.exit()

    print "Generating config files..."

    # check root path
    if not os.path.exists(options.root):
        print "%s path does not exist! Please create root path first." % options.root
        sys.exit()

    # check that fasta file exists
    if not os.path.exists(options.file):
        print "%s does not exist! Please check the path to the fasta file." % options.file
        sys.exit()
    
    # create log directory if it does not exist
    log_dir = "%s/log/" % (options.root)
    if not os.path.exists(log_dir):
        os.makedirs(log_dir)
    
    # create conf directory if it does not exist
    conf_dir = "%s/conf/" % (options.root)
    if not os.path.exists(conf_dir):
        os.makedirs(conf_dir)

    # open top config file
    conf_filename = "%s/%s" % (options.root, options.conf)
    if os.path.exists(conf_filename):
        conf_file = open(conf_filename, 'a')  # in append mode if file already exists
    else:
        conf_file = open(conf_filename, 'w')

    # create gene finding config files
    for step in GFIND_STEPS:
        gfind_conf_filename = '%s/conf/%s_%s.conf' % (options.root, options.name, step.lower())
        gfind_conf_file = open(gfind_conf_filename, 'w')
        gfind_conf_file.write(GFIND_TEMPLATE % {'root':options.root,
                                                'common_name':options.name,
                                                'fasta_file':options.file,
                                                'step':step})
        print "config file: %s" % gfind_conf_filename
        conf_file.write('%s\t%s\n' % (step.lower(), gfind_conf_filename))
        gfind_conf_file.close()
    
    # create gene function config file
    ## gfunc_conf_filename = '%s/conf/%s_gfunc.conf' % (options.root, options.name)
    ## gfunc_conf_file = open(gfunc_conf_filename, 'w')
    ## gfunc_conf_file.write(GFUNC_TEMPLATE % {'root':options.root,
    ##                                         'common_name':options.name})
    ## print "config file: %s" % gfunc_conf_filename
    ## gfunc_conf_file.close()
    
    ## conf_file.write('GFUNC\t%s\n' % gfunc_conf_filename)

    print "config file: %s appended" % conf_filename
    conf_file.close()
    
    print "generated for {%s, %s}" % (options.name, options.file)
    
### ---------------------------------------------------------------------------
if __name__ == '__main__':
    main()

    
