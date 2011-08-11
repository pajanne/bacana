=head1 NAME

Pathogens::Annotate::GeneFinding - pipeline for finding genes, inherits from VertRes::Pipelines.

=head1 SYNOPSIS

# Make the config files, which specifies the details to data roots:
echo 'GFIND gene_finding.conf' > ann_pipeline.conf

# Where gene_finding.conf contains:
root    => '/lustre/scratch103/sanger/ap12/metahit_pipeline//Ashahii_WAL8301',
module  => 'Pathogens::Annotate::GeneFinding',
prefix  => '_',
log	=> '/lustre/scratch103/sanger/ap12/metahit_pipeline//pipeline.log',

data => {
    fasta => '/lustre/scratch103/pathogen/pathpipe/metahit/seq-pipelines/Alistipes/shahii_WAL8301/ASSEMBLY/newbler_2009_11_26/Scaffolds.fna',
    common_name => 'Ashahii_WAL8301',
},

# Run the pipeline:
bash
source  ~/git/ann-pipeline/setup_annotation_environment.sh
/software/bin/perl ~/git/vr-codebase/scripts/run-pipeline -c /lustre/scratch101/sanger/ap12/ann_pipeline/ann_pipeline.conf -m 10000 -v -o -L

# Make sure it keeps running by adding that last to a regular cron job
*/30 * * * * umask 002; source /nfs/users/nfs_a/ap12/git/ann-pipeline/setup_annotation_environment.sh; /nfs/users/nfs_a/ap12/git/vr-codebase/scripts/run-pipeline -c /lustre/scratch101/sanger/ap12/ann_pipeline/ann_pipeline.conf -v -o -L;

=cut

package Pathogens::Annotate::GeneFinding;
use base qw(VertRes::Pipeline);

use strict;
use warnings;
use VRTrack::VRTrack;
use Utils;
use LSF;
use VertRes::Utils::FileSystem;

our @actions =
(
    {
        'name'     => 'create_sequence',
        'action'   => \&create_sequence,
        'requires' => \&create_sequence_requires, 
        'provides' => \&create_sequence_provides,
    },
    # ----------
    # TODO: sort out error while running glimmer with run-pipeline
    # {
    #     'name'     => 'run_glimmer3',
    #     'action'   => \&run_glimmer3,
    #     'requires' => \&run_glimmer3_requires, 
    #     'provides' => \&run_glimmer3_provides,
    # },
    # ----------
    {
        'name'     => 'run_prodigal',
        'action'   => \&run_prodigal,
        'requires' => \&run_prodigal_requires, 
        'provides' => \&run_prodigal_provides,
    },
    {
        'name'     => 'run_rnammer',
        'action'   => \&run_rnammer,
        'requires' => \&run_rnammer_requires, 
        'provides' => \&run_rnammer_provides,
    },
    {
        'name'     => 'run_trnascan',
        'action'   => \&run_trnascan,
        'requires' => \&run_trnascan_requires, 
        'provides' => \&run_trnascan_provides,
    },
    {
        'name'     => 'run_repeatscout',
        'action'   => \&run_repeatscout,
        'requires' => \&run_repeatscout_requires, 
        'provides' => \&run_repeatscout_provides,
    },
    {
        'name'     => 'run_alienhunter',
        'action'   => \&run_alienhunter,
        'requires' => \&run_alienhunter_requires, 
        'provides' => \&run_alienhunter_provides,
    },
    {
        'name'     => 'create_seq_chunks',
        'action'   => \&create_seq_chunks,
        'requires' => \&create_seq_chunks_requires, 
        'provides' => \&create_seq_chunks_provides,
    },
    # ----------
    # TODO: sort out LSF package to work for job array and dependencies
    # {
    #     'name'     => 'run_blastx',
    #     'action'   => \&run_blastx,
    #     'requires' => \&run_blastx_requires, 
    #     'provides' => \&run_blastx_provides,
    # },
    # {
    #     'name'     => 'run_rfamscan',
    #     'action'   => \&run_rfamscan,
    #     'requires' => \&run_rfamscan_requires, 
    #     'provides' => \&run_rfamscan_provides,
    # },
    # ----------
    {
        'name'     => 'run_merger',
        'action'   => \&run_merger,
        'requires' => \&run_merger_requires, 
        'provides' => \&run_merger_provides,
    },
);

our $options = 
{
    'perl_loc'             => '/software/bin',
    'py_loc'               => '/software/pathogen/external/lib/python/bin',

    # Executables
    'emboss_seqret_exec'   => '/software/pathogen/external/applications/EMBOSS-6.3.1-no-postgres/bin/seqret',
    'emboss_union_exec'    => '/software/pathogen/external/applications/EMBOSS-6.3.1-no-postgres/bin/union',
    'emboss_descseq_exec'  => '/software/pathogen/external/applications/EMBOSS-6.3.1-no-postgres/bin/descseq',

    'splitter_exec'        => '/nfs/users/nfs_a/ap12/genlibpy/genepy/convertors/splitter_wrapper.py',

    'glimmer3_exec'        => '/software/pathogen/external/applications/glimmer/glimmer/scripts/g3-iterated.csh',
    'glimmer2tab_exec'     => '/nfs/users/nfs_a/ap12/genlibpy/genepy/convertors/glimmer2tab.py',

    'prodigal_exec'        => '/software/pathogen/external/bin/prodigal',
    'prodigal2tab_exec'    => '/nfs/users/nfs_a/ap12/genlibpy/genepy/convertors/prodigal2tab.py',

    'trnascan_exec'        => '/software/pathogen/external/bin/tRNAscan-SE',
    'trnascan2tab_exec'    => '/nfs/users/nfs_a/ap12/genlibpy/genepy/convertors/trnascan2tab.py',

    'rfamscan_exec'        => '/software/pathogen/psu_svn/trunk/genexec/perl/src/rfam_scan.pl',
    'cm_file'              => '/lustre/scratch101/blastdb/Rfam/Rfam_9.1/Rfam.cm',
    'rfamscan2tab_exec'    => '/software/pathogen/psu_svn/trunk/genexec/perl/src/rfamscan2tab.pl',

    'blastall_exec'        => '/software/bin/blastall',
    'blastx_opts'          => '-p blastx -d /data/blastdb/uniprot',
    'blast2tab_exec'       => '/software/pathogen/psu_svn/trunk/genexec/perl/src/blast_formatter.pl',

    'repeatscout_bin'      => '/software/pathogen/external/applications/repeatscout/RepeatScout-1/',
    'repeatmasker_exec'    => '/software/pubseq/bin/RepeatMasker',
    'repeat2tab_exec'      => '/nfs/users/nfs_a/ap12/genlibpy/genepy/convertors/repeat2tab.py',

    'alienhunter_exec'     => '/nfs/users/nfs_a/ap12/lib/alien_hunter/alien_hunter',

    'rnammer_exec'         => '/nfs/users/nfs_a/ap12/lib/rnammer-1.2/rnammer',
    'rnammer2tab_exec'     => '/nfs/users/nfs_a/ap12/genlibpy/genepy/convertors/rnammer2tab.py',

    'merger_exec'          => '/nfs/users/nfs_a/ap12/genlibpy/genepy/pathtrack/gfind_merger.py',

    # LSF options
    'bsub_opts'            => '-q normal',
    'bsub_long_opts'       => '-q long',
    'bsub_array_opts'      => '',
    'bsub_mem'             => '2500',
    'bsub_lqueue'          => 'long',
};


### ---------------------------------------------------------------------------
### new
### ---------------------------------------------------------------------------
sub new 
{
    my ($class, @args) = @_;
    my $self = $class->SUPER::new(%$options,'actions'=>\@actions,@args);
    
    # check required options are provided
    $self->throw("Missing fasta option in config.\n") unless $self->{fasta};
    $self->throw("Missing common_name option in config.\n") unless $self->{common_name};
    $self->{lc_common_name} = lc($$self{common_name});

    # set fasta symlink
    $self->{fasta_symlink} = 'assembly.fna';

    # set sequence
    $self->{sequence} = 'sequence.fna';

    # set sequence chunks path
    $self->{seq_chunks_path} = 'seq_chunks';

    # set embl sequence & feature table file
    $self->{embl} = 'sequence.embl';

    return $self;
}


### ---------------------------------------------------------------------------
### create_sequence
### ---------------------------------------------------------------------------
sub create_sequence_requires
{
    my ($self) = @_;
    my @requires;
    push(@requires, "$$self{fasta}");
    return \@requires;
}

sub create_sequence_provides
{
    my ($self) = @_;
    my @provides;
    push(@provides, "$$self{fasta_symlink}");
    push(@provides, "$$self{sequence}");
    return \@provides;
}

sub create_sequence
{
    my ($self, $path, $action_lock) = @_;

    # create symlink to assembly file
    Utils::relative_symlink($$self{fasta}, $path . '/' . $$self{fasta_symlink}); 

    # dynamic script to be run by LSF
    open(my $fh,'>', "$path/_create_seq.pl") or Utils::error("$path/_create_seq.pl: $!");
    print $fh
qq[
use strict;
use warnings;
use Utils;

# create sequence file
Utils::CMD("$$self{emboss_union_exec} -sequence $$self{fasta} -stdout Yes -auto Yes | $$self{emboss_descseq_exec} -filter Yes -name '$$self{common_name}' -auto Yes > $$self{sequence}");
if ( ! -s "$$self{sequence}" ) { 
    Utils::error("The command ended with an error:\\n\\$$self{emboss_union_exec} -sequence $$self{fasta} -stdout Yes -auto Yes | $$self{emboss_descseq_exec} -filter Yes -name '$$self{common_name}' -auto Yes > $$self{sequence}\\n");
}
];
    close($fh);
    LSF::run($action_lock, $path, "_$$self{common_name}_create_seq", $self, "$$self{perl_loc}/perl -w _create_seq.pl");

    return $$self{'No'};
}

### ---------------------------------------------------------------------------
### create_seq_chunks
### ---------------------------------------------------------------------------
sub create_seq_chunks_requires
{
    my ($self) = @_;
    my @requires;
    push(@requires, "$$self{sequence}");
    return \@requires;
}

sub create_seq_chunks_provides
{
    my ($self) = @_;
    my @provides;
    push(@provides, "$$self{seq_chunks_path}");
    # splitter create file with sequence name in lowercase
    push(@provides, "$$self{seq_chunks_path}/$$self{lc_common_name}_1.fasta");
    return \@provides;
}

sub create_seq_chunks
{
    my ($self, $path, $action_lock) = @_;

    # create sequence chunk files
    Utils::CMD(qq[$$self{py_loc}/python $$self{splitter_exec} --sequence $path/$$self{sequence} --outdir $path/$$self{seq_chunks_path}]);

    return $$self{'Yes'};
}

### ---------------------------------------------------------------------------
### run_merger
### ---------------------------------------------------------------------------
sub run_merger_requires
{
    my ($self) = @_;
    my @requires;
    push(@requires, "$$self{fasta_symlink}");
    push(@requires, "$$self{common_name}.prodigal.tab");
    push(@requires, "$$self{common_name}.g3.tab");
    return \@requires;
}

sub run_merger_provides
{
    my ($self) = @_;
    my @provides;
    push(@provides, "$$self{embl}");
    return \@provides;
}

sub run_merger
{
    my ($self, $path, $lock_file) = @_;

    # dynamic script to be run by LSF
    open(my $fh,'>', "$path/_merger.pl") or Utils::error("$path/_merger.pl: $!");
    print $fh
qq[
use strict;
use warnings;
use Utils;

# run merger to create EMBL file
Utils::CMD("$$self{py_loc}/python $$self{merger_exec} -s $$self{fasta_symlink} -p $$self{common_name}.prodigal.tab -g $$self{common_name}.g3.tab -o $$self{embl} -n $$self{common_name} -l XXX");
if ( ! -s "$$self{embl}" ) { 
    Utils::error("The command ended with an error:\\n\\t$$self{py_loc}/python $$self{merger_exec} -s $$self{fasta_symlink} -p $$self{common_name}.prodigal.tab -g $$self{common_name}.g3.tab -o $$self{embl} -n $$self{common_name} -l XXX\\n");
} else {
    # Tidy-up

}
];
    close($fh);
    LSF::run($lock_file, $path, "_$$self{common_name}_merger", $self, "$$self{perl_loc}/perl -w _merger.pl");

    return $$self{'No'};
}

### ---------------------------------------------------------------------------
### run_glimmer3
### ---------------------------------------------------------------------------
sub run_glimmer3_requires
{
    my ($self) = @_;
    my @requires;
    push(@requires, "$$self{sequence}");
    return \@requires;
}

sub run_glimmer3_provides
{
    my ($self) = @_;
    my @provides;
    push(@provides, "$$self{common_name}.g3.tab");
    return \@provides;
}

sub run_glimmer3
{
    my ($self, $path, $lock_file) = @_;

    # dynamic script to be run by LSF
    open(my $fh,'>', "$path/_glimmer3.pl") or Utils::error("$path/_glimmer3.pl: $!");
    print $fh
qq[
use strict;
use warnings;
use Utils;

# run glimmer3
Utils::CMD("$$self{glimmer3_exec} $$self{sequence} $$self{common_name}");
if ( ! -s "$$self{common_name}.predict" ) { 
    Utils::error("The command ended with an error:\\n\\t$$self{glimmer3_exec} $$self{sequence} $$self{common_name}\\n");
} else {
    # Tidy-up
    unlink("$$self{common_name}.longorfs");
    unlink("$$self{common_name}.train");
    unlink("$$self{common_name}.icm");
    unlink("$$self{common_name}.run1.detail");
    unlink("$$self{common_name}.run1.predict");
    unlink("$$self{common_name}.coords");
    unlink("$$self{common_name}.upstream");
    unlink("$$self{common_name}.motif");
    unlink("$$self{common_name}.detail");

    # Convert glimmer3 results into EMBL feature table
    Utils::CMD("$$self{py_loc}/python $$self{glimmer2tab_exec} -i $$self{common_name}.predict -o $$self{common_name}.g3.tab");
    if ( ! -s "$$self{common_name}.g3.tab" ) { 
        Utils::error("The command ended with an error:\\n\\t$$self{py_loc}/python $$self{glimmer2tab_exec} -i $$self{common_name}.predict -o $$self{common_name}.g3.tab\\n");
    }

    # Tidy-up
    unlink("$$self{common_name}.predict");
}
];
    close($fh);
    LSF::run($lock_file, $path, "_$$self{common_name}_g3", {bsub_opts=>$$self{bsub_opts}}, "$$self{perl_loc}/perl -w _glimmer3.pl");

    return $$self{'No'};
}

### ---------------------------------------------------------------------------
### run_prodigal
### ---------------------------------------------------------------------------
sub run_prodigal_requires
{
    my ($self) = @_;
    my @requires;
    push(@requires, "$$self{sequence}");
    return \@requires;
}

sub run_prodigal_provides
{
    my ($self) = @_;
    my @provides;
    push(@provides, "$$self{common_name}.prodigal.tab");
    return \@provides;
}

sub run_prodigal
{
    my ($self, $path, $lock_file) = @_;

    # dynamic script to be run by LSF
    open(my $fh,'>', "$path/_prodigal.pl") or Utils::error("$path/_prodigal.pl: $!");
    print $fh
qq[
use strict;
use warnings;
use Utils;

# run prodigal
Utils::CMD("$$self{prodigal_exec} < $$self{sequence} > $$self{common_name}.prodigal");
if ( ! -s "$$self{common_name}.prodigal" ) { 
    Utils::error("The command ended with an error:\\n\\t$$self{prodigal_exec} < $$self{sequence} > $$self{common_name}.prodigal\\n");
} else {
    # Convert prodigal results into EMBL feature table
    Utils::CMD("$$self{py_loc}/python $$self{prodigal2tab_exec} -i $$self{common_name}.prodigal -o $$self{common_name}.prodigal.tab");
    if ( ! -s "$$self{common_name}.prodigal.tab" ) { 
        Utils::error("The command ended with an error:\\n\\t$$self{py_loc}/python $$self{prodigal2tab_exec} -i $$self{common_name}.prodigal -o $$self{common_name}.prodigal.tab\\n");
    }

    # Tidy-up
    unlink("$$self{common_name}.prodigal");
}
];
    close($fh);
    LSF::run($lock_file, $path, "_$$self{common_name}_prodigal", $self, "$$self{perl_loc}/perl -w _prodigal.pl");

    return $$self{'No'};
}

### ---------------------------------------------------------------------------
### run_repeatscout
### ---------------------------------------------------------------------------
sub run_repeatscout_requires
{
    my ($self) = @_;
    my @requires;
    push(@requires, "$$self{sequence}");
    return \@requires;
}

sub run_repeatscout_provides
{
    my ($self) = @_;
    my @provides;
    push(@provides, "$$self{common_name}.repeatscout.tab");
    return \@provides;
}

sub run_repeatscout
{
    my ($self, $path, $lock_file) = @_;

    # dynamic script to be run by LSF
    open(my $fh,'>', "$path/_repeatscout.pl") or Utils::error("$path/_repeatscout.pl: $!");
    print $fh
qq[
use strict;
use warnings;
use Utils;

# step1 - run build_lmer_table
# creates a file that tabulates the frequency of all l-mers in the sequence to be analyzed [option -l to be set?]
Utils::CMD("$$self{repeatscout_bin}/build_lmer_table -sequence $$self{sequence} -freq $$self{common_name}.repeatscout.lmer");
if ( ! -s "$$self{common_name}.repeatscout.lmer" ) { 
    Utils::error("The command ended with an error:\\n\\t$$self{repeatscout_bin}/build_lmer_table -sequence $$self{sequence} -freq $$self{common_name}.repeatscout.lmer\\n");
}

# step2 - run RepeatScout
# takes this table and the sequence and produces a fasta file that contains all the repetitive elements that it could find.
Utils::CMD("$$self{repeatscout_bin}/RepeatScout -sequence $$self{sequence} -output $$self{common_name}.repeatscout -freq $$self{common_name}.repeatscout.lmer");
if ( ! -s "$$self{common_name}.repeatscout" ) { 
    Utils::error("The command ended with an error:\\n\\t$$self{repeatscout_bin}/RepeatScout -sequence $$self{sequence} -output $$self{common_name}.repeatscout -freq $$self{common_name}.repeatscout.lmer\\n");
}

# step3 - run filter-stage-1.prl script
# on the output of RepeatScout to remove low-complexity and tandem elements
Utils::CMD("cat $$self{common_name}.repeatscout | $$self{repeatscout_bin}/filter-stage-1.prl > $$self{common_name}.repeatscout.prl1");
if ( ! -s "$$self{common_name}.repeatscout.prl1" ) { 
    Utils::error("The command ended with an error:\\n\\tcat $$self{common_name}.repeatscout | $$self{repeatscout_bin}/filter-stage-1.prl > $$self{common_name}.repeatscout.prl1\\n");
}

# step4 - run RepeatMasker
Utils::CMD("$$self{repeatmasker_exec} -lib $$self{common_name}.repeatscout.prl1 $$self{sequence}");
if ( ! -s "$$self{sequence}.out" ) { 
    Utils::error("The command ended with an error:\\n\\t$$self{repeatmasker_exec} -lib $$self{common_name}.repeatscout.prl1 $$self{sequence}\\n");
}

# step5 - run filter-stage-2.prl script
# filters out any repeat element that does not appear a certain number of times (by default, 10)
Utils::CMD("cat $$self{common_name}.repeatscout.prl1 | $$self{repeatscout_bin}/filter-stage-2.prl --cat=$$self{sequence}.out --thresh=20 > $$self{common_name}.repeatscout.prl2");
if ( ! -s "$$self{common_name}.repeatscout.prl2" ) { 
    Utils::error("The command ended with an error:\\n\\tcat $$self{common_name}.repeatscout.prl1 | $$self{repeatscout_bin}/filter-stage-2.prl --cat=$$self{common_name}.repeatscout.out --thresh=20 > $$self{common_name}.repeatscout.prl2\\n");
} else {
    # Tidy-up
    unlink("$$self{sequence}.cat");
    unlink("$$self{sequence}.out");
    unlink("$$self{sequence}.masked");
    unlink("$$self{sequence}.tbl");
}

# step6 - run RepeatMasker
Utils::CMD("$$self{repeatmasker_exec} -lib $$self{common_name}.repeatscout.prl2 $$self{sequence}");
if ( ! -s "$$self{sequence}.out" ) { 
    Utils::error("The command ended with an error:\\n\\t$$self{repeatmasker_exec} -lib $$self{common_name}.repeatscout.prl2 $$self{sequence}\\n");
} else {
    # Convert to EMBL feature table
    Utils::CMD("$$self{py_loc}/python $$self{repeat2tab_exec} -i $$self{sequence}.out -o $$self{common_name}.repeatscout.tab");
    if ( ! -s "$$self{common_name}.repeatscout.tab" ) { 
        Utils::error("The command ended with an error:\\n\\t$$self{py_loc}/python $$self{repeat2tab_exec} -i $$self{sequence}.out -o $$self{common_name}.repeatscout.tab\\n");
    }

    # Tidy-up
    unlink("$$self{common_name}.repeatscout.lmer");
    unlink("$$self{common_name}.repeatscout");
    unlink("$$self{common_name}.repeatscout.prl1");
    unlink("$$self{common_name}.repeatscout.prl2");
    unlink("$$self{sequence}.cat");
    unlink("$$self{sequence}.ori.out");
    unlink("$$self{sequence}.out");
    unlink("$$self{sequence}.log");
    unlink("$$self{sequence}.masked");
    unlink("$$self{sequence}.tbl");
}
];
    close($fh);
    LSF::run($lock_file, $path, "_$$self{common_name}_repeatscout", {memory=>$$self{bsub_mem}}, "$$self{perl_loc}/perl -w _repeatscout.pl");

    return $$self{'No'};
}

### ---------------------------------------------------------------------------
### run_trnascan
### ---------------------------------------------------------------------------
sub run_trnascan_requires
{
    my ($self) = @_;
    my @requires;
    push(@requires, "$$self{sequence}");
    return \@requires;
}

sub run_trnascan_provides
{
    my ($self) = @_;
    my @provides;
    push(@provides, "$$self{common_name}.trnascan.tab");
    return \@provides;
}

sub run_trnascan
{
    my ($self, $path, $lock_file) = @_;

    # dynamic script to be run by LSF
    open(my $fh,'>', "$path/_trnascan.pl") or Utils::error("$path/_trnascan.pl: $!");
    print $fh
qq[
use strict;
use warnings;
use Utils;

# run trnascan
Utils::CMD("$$self{trnascan_exec} -P -o $$self{common_name}.trnascan -q -b -Q -C $$self{sequence}");
if ( ! -s "$$self{common_name}.trnascan" ) { 
    Utils::error("The command ended with an error:\\n\\t$$self{trnascan_exec} -P -o $$self{common_name}.trnascan -q -b -Q -C $$self{sequence}\\n");
} else {
    # Convert trnascan results into EMBL feature table
    Utils::CMD("$$self{py_loc}/python $$self{trnascan2tab_exec} -i $$self{common_name}.trnascan -o $$self{common_name}.trnascan.tab");
    if ( ! -s "$$self{common_name}.trnascan.tab" ) { 
        Utils::error("The command ended with an error:\\n\\t$$self{py_loc}/python $$self{trnascan2tab_exec} -i $$self{common_name}.trnascan -o $$self{common_name}.trnascan.tab\\n");
    }

    # Tidy-up
    unlink("$$self{common_name}.trnascan");
}
];
    close($fh);
    LSF::run($lock_file, $path, "_$$self{common_name}_trnascan", {bsub_opts=>$$self{bsub_long_opts}}, "$$self{perl_loc}/perl -w _trnascan.pl");

    return $$self{'No'};
}

### ---------------------------------------------------------------------------
### run_rfamscan
### ---------------------------------------------------------------------------
sub run_rfamscan_requires
{
    my ($self) = @_;
    my @requires;
    push(@requires, "$$self{sequence}");
    push(@requires, "$$self{seq_chunks_path}");
    return \@requires;
}

sub run_rfamscan_provides
{
    my ($self) = @_;
    my @provides;
    push(@provides, "rfamscan.done");
    return \@provides;
}

sub run_rfamscan
{
    my ($self, $path, $lock_file) = @_;

    # The rfam file already exists
    if ( -e "$path/$$self{common_name}.rfam.tab" )
    {
        Utils::CMD("touch $path/rfamscan.done");
        return;
    }

    # create tmp directory for results
    my $rfamdir = $path . '/_rfamscan';
    Utils::create_dir($rfamdir);
    
    # Because this subroutine returns as if it has already finished, a custom jids_file must
    # be used: Pipeline.pm will delete the $lock_file.
    my $jids_file = "$path/$$self{prefix}rfamscan_chunks.jid";
    my $status = LSF::is_job_running($jids_file);
    if ( $status&$LSF::Running ) { return; }
    if ( $status&$LSF::Error ) { $self->warn("Some jobs failed: $jids_file\n"); }

    # run rfamscan on chunked sequences on LSF
    my $chunks = get_chunk_number($self, $path);
    my $rfamscan_cmd = qq($$self{rfamscan_exec} -t 30 $$self{cm_file} $path/$$self{seq_chunks_path}/$$self{lc_common_name}_\$LSB_JOBINDEX.fasta > $$self{lc_common_name}_\$LSB_JOBINDEX.rfam);
    LSF::run_array($jids_file, $rfamdir, "_$$self{lc_common_name}_rfamscan", $chunks, {bsub_opts=>$$self{bsub_opts}}, $rfamscan_cmd);

    # concat results & convert them into EMBL feature table & remove tmp dir on LSF with dependency on previous job
    my $concat_cmd = "find $rfamdir -name \"$$self{lc_common_name}_*.rfam\" | xargs cat | sort >> $$self{common_name}.rfam";
    my $convert_cmd = "$$self{rfamscan2tab_exec} -i $$self{common_name}.rfam -s $$self{sequence} -o $$self{common_name}.rfam.tab";
    my $tidyup_cmd = "rm -rf $rfamdir; rm -f $$self{common_name}.rfam";
    my $res_cmd = $concat_cmd . " ; " . $convert_cmd . " ; " . $tidyup_cmd; 
    LSF::run_dependency($jids_file, $path, "_$$self{lc_common_name}_rfamscan",  "_$$self{lc_common_name}_rfamres", {bsub_opts=>$$self{bsub_opts}}, $res_cmd);

    return $$self{'Yes'};
}

### ---------------------------------------------------------------------------
### run_blastx
### ---------------------------------------------------------------------------
sub run_blastx_requires
{
    my ($self) = @_;
    my @requires;
    push(@requires, "$$self{sequence}");
    push(@requires, "$$self{seq_chunks_path}");
    return \@requires;
}

sub run_blastx_provides
{
    my ($self) = @_;
    my @provides;
    push(@provides, "blastx.done");
    return \@provides;
}

sub run_blastx
{
    my ($self, $path, $lock_file) = @_;

    # The big blastx file already exists
    if ( -e "$path/$$self{common_name}.blastx.tab.gz" )
    {
        Utils::CMD("touch $path/blastx.done");
        return;
    }

    # create tmp directory for results
    my $blastxdir = $path . '/_blastx';
    Utils::create_dir($blastxdir);

    # Because this subroutine returns as if it has already finished, a custom jids_file must
    # be used: Pipeline.pm will delete the $lock_file.
    my $jids_file = "$path/$$self{prefix}blastx_chunks.jid";
    my $status = LSF::is_job_running($jids_file);
    if ( $status&$LSF::Running ) { return; }
    if ( $status&$LSF::Error ) { $self->warn("Some jobs failed: $jids_file\n"); }

    # run blastx on chunked sequences on LSF and format results into EMBL feature table
    my $chunks = get_chunk_number($self, $path);
    my $blastx_cmd = qq($$self{blastall_exec} $$self{blastx_opts} -i $path/$$self{seq_chunks_path}/$$self{lc_common_name}_\$LSB_JOBINDEX.fasta | $$self{blast2tab_exec} -t -o $$self{lc_common_name}_\$LSB_JOBINDEX.blastx);
    LSF::run_array($jids_file, $blastxdir, "_$$self{lc_common_name}_blastx", $chunks, {bsub_opts=>$$self{bsub_opts}}, $blastx_cmd);

    # concat blast results on LSF with dependency on previous job
    my $concat_cmd = "find $blastxdir -name \"$$self{lc_common_name}_*.blastx.tab\" | xargs cat | sort >> $$self{common_name}.blastx.tab";
    my $zip_cmd = "gzip $$self{common_name}.blastx.tab";
    #my $tidyup_cmd = "rm -rf $blastxdir";
    my $tidyup_cmd = "";
    my $res_cmd = $concat_cmd . " ; " . $zip_cmd . " ; " . $tidyup_cmd;
    LSF::run_dependency($jids_file, $path, "_$$self{lc_common_name}_blastx",  "_$$self{lc_common_name}_blastxres", {bsub_opts=>$$self{bsub_opts}}, $res_cmd);

    return $$self{'Yes'};
}

### ---------------------------------------------------------------------------
### run_alienhunter
### ---------------------------------------------------------------------------
sub run_alienhunter_requires
{
    my ($self) = @_;
    my @requires;
    push(@requires, "$$self{sequence}");
    return \@requires;
}

sub run_alienhunter_provides
{
    my ($self) = @_;
    my @provides;
    push(@provides, "$$self{common_name}.alienhunter.tab");
    return \@provides;
}

sub run_alienhunter
{
    my ($self, $path, $lock_file) = @_;

    # dynamic script to be run by LSF
    open(my $fh,'>', "$path/_alienhunter.pl") or Utils::error("$path/_alienhunter.pl: $!");
    print $fh
qq[
use strict;
use warnings;
use Utils;

# run alienhunter
Utils::CMD("$$self{alienhunter_exec} $$self{sequence} $$self{common_name}.alienhunter.tab -c");
if ( ! -s "$$self{common_name}.alienhunter.tab" ) { 
    Utils::error("The command ended with an error:\\n\\t$$self{alienhunter_exec} $$self{sequence} $$self{common_name}.alienhunter.tab -c\\n");
} else {
    # Tidy-up
    unlink("$$self{common_name}.alienhunter.tab.sco");
    unlink("$$self{common_name}.alienhunter.tab.plot");
    unlink("$$self{common_name}.alienhunter.tab.opt");
    unlink("$$self{common_name}.alienhunter.tab.opt.plot");
}
];
    close($fh);
    LSF::run($lock_file, $path, "_$$self{common_name}_alienhunter", {bsub_opts=>'-q long -M2500000 -R"select[mem>2500] rusage[mem=2500]"'}, "$$self{perl_loc}/perl -w _alienhunter.pl");

    return $$self{'No'};
}

### ---------------------------------------------------------------------------
### run_rnammer
### ---------------------------------------------------------------------------
sub run_rnammer_requires
{
    my ($self) = @_;
    my @requires;
    push(@requires, "$$self{sequence}");
    return \@requires;
}

sub run_rnammer_provides
{
    my ($self) = @_;
    my @provides;
    push(@provides, "$$self{common_name}.rnammer.tab");
    return \@provides;
}

sub run_rnammer
{
    my ($self, $path, $lock_file) = @_;

    # dynamic script to be run by LSF
    open(my $fh,'>', "$path/_rnammer.pl") or Utils::error("$path/_rnammer.pl: $!");
    print $fh
qq[
use strict;
use warnings;
use Utils;

# run rnammer
Utils::CMD("$$self{rnammer_exec} -S bac -gff $$self{common_name}.rnammer.gff < $$self{sequence}");
if ( ! -s "$$self{common_name}.rnammer.gff" ) { 
    Utils::error("The command ended with an error:\\n\\t$$self{rnammer_exec} -S bac -gff $$self{common_name}.rnammer.gff < $$self{sequence}\\n");
} else {
    # Convert rnammer results into EMBL feature table
    Utils::CMD("$$self{py_loc}/python $$self{rnammer2tab_exec} -i $$self{common_name}.rnammer.gff -o $$self{common_name}.rnammer.tab");
    if ( ! -s "$$self{common_name}.rnammer.tab" ) { 
        Utils::error("The command ended with an error:\\n\\t$$self{py_loc}/python $$self{rnammer2tab_exec} -i $$self{common_name}.rnammer.gff -o $$self{common_name}.rnammer.tab\\n");
    }

    # Tidy-up
    unlink("$$self{common_name}.rnammer.gff");
}
];
    close($fh);
    LSF::run($lock_file, $path, "_$$self{common_name}_rnammer", {bsub_opts=>$$self{bsub_opts}}, "$$self{perl_loc}/perl -w _rnammer.pl");

    return $$self{'No'};
}

### ---------------------------------------------------------------------------
### utility methods
### ---------------------------------------------------------------------------
sub get_chunk_number
{
    my ($self, $path) = @_;
    
    my @files = <$path/$$self{seq_chunks_path}/$$self{lc_common_name}_*.fasta>;
    my $count = @files;
    return $count;
}

1;

