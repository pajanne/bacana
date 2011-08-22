#!/usr/bin/env python
'''
Created on Aug 19, 2011
by
@author: Anne Pajon (ap12)
Copyright (c) 2011 Wellcome Trust Sanger Institute. All rights reserved.
'''

from optparse import OptionParser
import sys, os
import shutil

### ---------------------------------------------------------------------------
def main():
    usage = "usage: %prog -l LIST"
    parser = OptionParser(usage=usage)
    parser.add_option("-l", metavar="FILE", help="FILE containing the list of all files", action="store", type="string", dest="list")
    (options, args) = parser.parse_args()
    
    if not (options.list):
        parser.print_help()
        sys.exit()

    print "Checking metahit ref fasta files..."
    
    # Read list of files
    for line in open(options.list, "r"):
        if line[0] == '!':
            continue
        if line.strip():
            line = line.strip()
            if line.count('||') > 0:
                # !common_name||genus||species_strain||path_to_fasta_file
                list = line.split('||')
                common_name = list[0]
                genus = list[1]
                species = list[2]
                new_fasta_file_path = "/nfs/pathogen/metahit/refs/%s/%s/improved/" % (genus, species)
                new_fasta_file_name = "%s_%s.fasta" % (genus, species)
                fasta_file = list[3]
                
                if not os.path.exists(fasta_file):
                    print "NOT FOUND %s" % fasta_file
                else:
                    if not os.path.isfile(fasta_file):
                        print "NO FILE   %s" % fasta_file
                    else:
                        print "FOUND     %s" % fasta_file
                        new_fasta_file = "%s/%s" % (new_fasta_file_path, new_fasta_file_name)
                        print "Copying %s to %s" % (fasta_file, new_fasta_file)
                        if not os.path.exists(new_fasta_file_path):
                            os.makedirs(new_fasta_file_path)
                        shutil.copyfile(fasta_file, new_fasta_file)

### ---------------------------------------------------------------------------
if __name__ == '__main__':
    main()
        
