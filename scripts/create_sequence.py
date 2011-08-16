## use strict;
## use warnings;
## use Utils;

## # create sequence file
## Utils::CMD("/software/pathogen/external/applications/EMBOSS-6.3.1-no-postgres/bin/union -sequence /nfs/users/nfs_a/ap12/git/ann-pipeline/tests/../data/Scaffolds.fna -stdout Yes -auto Yes | /software/pathogen/e
## xternal/applications/EMBOSS-6.3.1-no-postgres/bin/descseq -filter Yes -name 'test' -auto Yes > sequence.fna");
## if ( ! -s "sequence.fna" ) { 
##     Utils::error("The command ended with an error:\n\/software/pathogen/external/applications/EMBOSS-6.3.1-no-postgres/bin/union -sequence /nfs/users/nfs_a/ap12/git/ann-pipeline/tests/../data/Scaffolds.fna -st
## dout Yes -auto Yes | /software/pathogen/external/applications/EMBOSS-6.3.1-no-postgres/bin/descseq -filter Yes -name 'test' -auto Yes > sequence.fna\n");
## }

# union -sequence Scaffolds.fna -stdout Yes -auto Yes | descseq -filter Yes -name 'test' -auto Yes > sequence.fna
