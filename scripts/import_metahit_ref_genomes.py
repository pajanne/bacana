#!/usr/bin/env python
'''
Created on Aug 19, 2011
by
@author: Anne Pajon (ap12)
Copyright (c) 2011 Wellcome Trust Sanger Institute. All rights reserved.
'''

from optparse import OptionParser
import sys, os

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
            fasta_file = line.strip()
            if not os.path.exists(fasta_file):
                print "NOT FOUND %s" % fasta_file
            else:
                print "FOUND     %s" % fasta_file

### ---------------------------------------------------------------------------
if __name__ == '__main__':
    main()
        
