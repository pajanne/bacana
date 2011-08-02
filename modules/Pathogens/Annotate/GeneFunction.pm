=head1 NAME

Pathogens::Annotate::GeneFunction - pipeline to assign gene functions, inherits from VertRes::Pipelines.

=head1 SYNOPSIS

# Make the config files, which specifies the details to data roots:
echo 'GFUNC gene_function.conf' > pipeline.conf

# Where gene_function.conf contains:
root    => '/lustre/scratch103/sanger/ap12/metahit_analysis/Ashahii_WAL8301',
module  => 'Pathogens::Annotate::GeneFunction',
prefix  => '_',
log	=> '/lustre/scratch103/sanger/ap12/metahit_analysis/pipeline.log',

data => {
    embl => '/nfs/users/nfs_a/ap12/metahit_data/EMBLSubmission/Ashahii_WAL8301.4dep.embl',
    common_name => 'Ashahii_WAL8301',
},

# Run the pipeline:
run-pipeline -c pipeline.conf -o -v -v

# Make sure it keeps running by adding that last to a regular cron job
*/30 * * * * umask 002; source /nfs/users/nfs_a/ap12/pathtrack/crontab_env_variables.sh; run-pipeline -c /nfs/users/nfs_a/ap12/pathtrack/pipeline.conf -v -o -L;

=cut

package PathTrack::GeneFunction;
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
        'name'     => 'import_embl',
        'action'   => \&import_embl,
        'requires' => \&import_embl_requires, 
        'provides' => \&import_embl_provides,
    },
    {
        'name'     => 'run_pfamscan',
        'action'   => \&run_pfamscan,
        'requires' => \&run_pfamscan_requires, 
        'provides' => \&run_pfamscan_provides,
    },
    {
        'name'     => 'run_tmhmm',
        'action'   => \&run_tmhmm,
        'requires' => \&run_tmhmm_requires, 
        'provides' => \&run_tmhmm_provides,
    },
    {
        'name'     => 'create_seq_chunks',
        'action'   => \&create_seq_chunks,
        'requires' => \&create_seq_chunks_requires, 
        'provides' => \&create_seq_chunks_provides,
    },
    {
        'name'     => 'run_blastp',
        'action'   => \&run_blastp,
        'requires' => \&run_blastp_requires, 
        'provides' => \&run_blastp_provides,
    },
    {
        'name'     => 'run_signalp',
        'action'   => \&run_signalp,
        'requires' => \&run_signalp_requires, 
        'provides' => \&run_signalp_provides,
    },

    # ----------
    # iprscan is too unstable to be ran within a pipeline
    # {
    #     'name'     => 'run_iprscan',
    #     'action'   => \&run_iprscan,
    #     'requires' => \&run_iprscan_requires, 
    #     'provides' => \&run_iprscan_provides,
    # },
    # ----------
);

our $options = 
{
    # Executables
    'emboss_extractfeat_exec' => '/software/pathogen/external/applications/EMBOSS-6.3.1-no-postgres/bin/extractfeat',
    'emboss_transeq_exec'  => '/software/pathogen/external/applications/EMBOSS-6.3.1-no-postgres/bin/transeq',

    'extractfeat_exec'     => '/nfs/users/nfs_a/ap12/genlibpy/genepy/convertors/extractfeat_wrapper.py',

    'iprscan_exec'         => '/software/iprscan/bin/iprscan',
    'iprscan2embl_exec'    => '/nfs/users/nfs_a/ap12/genlibpy/genepy/convertors/iprscan2embl.py',

    'blastall_exec'        => '/software/bin/blastall',
    'blastp_opts'          => '-p blastp -d /data/blastdb/uniprot',
    'blast2tab_exec'       => '/software/pathogen/psu_svn/trunk/genexec/perl/src/blast_formatter.pl',

    'tmhmm_exec'           => '/software/pathogen/external/applications/TMHMM/TMHMM2.0c/bin/tmhmm',
    'tmhmm2embl_exec'      => '/nfs/users/nfs_a/ap12/genlibpy/genepy/convertors/tmhmm2embl.py',

    'signalp_exec'         => '/software/pathogen/external/applications/signalp/signalp//signalp',
    'signalp_type'         => 'gram+', # type 'euk', 'gram+', 'gram-'

    'pfamscan_exec'        => '/software/pathogen/external/applications/pfam_scan/bin/pfam_scan.pl',
    'pfam_dir'             => '/data/blastdb',
    'pfam2embl_exec'       => '/nfs/users/nfs_a/ap12/genlibpy/genepy/convertors/pfam2embl.py',
    'pfam2go'              => '/nfs/users/nfs_a/ap12/tmp/go/pfam2go',
    'go_map'               => '/nfs/users/nfs_a/ap12/tmp/go/map',

    'bsub_opts'            => '-q normal',
    'bsub_long_opts'       => '-q long',
    'bsub_small_opts'      => '-q small',
    'bsub_array_opts'      => '',
};


### ---------------------------------------------------------------------------
### new
### ---------------------------------------------------------------------------
sub new 
{
    my ($class, @args) = @_;
    my $self = $class->SUPER::new(%$options,'actions'=>\@actions,@args);
    
    # check required options are provided
    #$self->throw("Missing fasta option in config.\n") unless $self->{fasta};
    #$self->throw("Missing cds option in config.\n") unless $self->{cds};
    $self->throw("Missing embl option in config.\n") unless $self->{embl};
    $self->throw("Missing common_name option in config.\n") unless $self->{common_name};
    $self->{lc_common_name} = lc($$self{common_name});

    # set embl symlink
    $self->{embl_symlink} = 'sequence.embl';

    # set fasta protein sequence file
    $self->{pep} = 'sequence.pep';

    # set sequence id mapping file between EMBOSS and EMBL 
    $self->{seqids} = 'sequence.seqids';

    # set sequence chunks path
    $self->{seq_chunks_path} = 'seq_chunks';

    return $self;
}


### ---------------------------------------------------------------------------
### import_embl
### ---------------------------------------------------------------------------
sub import_embl_requires
{
    my ($self) = @_;
    my @requires;
    push(@requires, "$$self{embl}");
    return \@requires;
}

sub import_embl_provides
{
    my ($self) = @_;
    my @provides;
    push(@provides, "$$self{embl_symlink}");
    push(@provides, "$$self{pep}");
    push(@provides, "$$self{seqids}");
    return \@provides;
}

sub import_embl
{
    my ($self, $path, $action_lock) = @_;

    # create symlink to embl file
    Utils::relative_symlink($$self{embl}, $path . '/' . $$self{embl_symlink}); 

    # create protein sequences in fasta format
    Utils::CMD(qq[$$self{emboss_extractfeat_exec} -sequence embl::$$self{embl} -type CDS -featinname YES -stdout Yes -auto Yes | $$self{emboss_transeq_exec} -filter Yes -clean -outseq fasta::$path/$$self{pep}]);

    # create mapping file of sequence ids
    Utils::CMD(qq[$$self{emboss_extractfeat_exec} -sequence embl::$$self{embl} -type CDS -featinname YES -describe locus_tag -stdout Yes -auto Yes | $$self{emboss_transeq_exec} -filter Yes -stdout Yes -auto Yes | grep '>' > $path/$$self{seqids}]);

    return $$self{'Yes'};
}


### ---------------------------------------------------------------------------
### create_seq_chunks
### ---------------------------------------------------------------------------
sub create_seq_chunks_requires
{
    my ($self) = @_;
    my @requires;
    push(@requires, "$$self{embl}");
    return \@requires;
}

sub create_seq_chunks_provides
{
    my ($self) = @_;
    my @provides;
    push(@provides, "$$self{seq_chunks_path}");
    push(@provides, "$$self{seq_chunks_path}/$$self{common_name}_1.pep");
    return \@provides;
}

sub create_seq_chunks
{
    my ($self, $path, $action_lock) = @_;

    # extract CDS features
    Utils::CMD(qq[python $$self{extractfeat_exec} --sequence=$$self{embl} --name=$$self{common_name} --outdir=$path/$$self{seq_chunks_path}]);

    return $$self{'Yes'};
}


### ---------------------------------------------------------------------------
### run_iprscan
### ---------------------------------------------------------------------------
sub run_iprscan_requires
{
    my ($self) = @_;
    my @requires;
    push(@requires, "$$self{embl}");
    push(@requires, "$$self{pep}");
    push(@requires, "$$self{seqids}");
    push(@requires, "$$self{seq_chunks_path}");
    return \@requires;
}

sub run_iprscan_provides
{
    my ($self) = @_;
    my @provides;
    push(@provides, "$$self{common_name}.iprscan.embl");
    push(@provides, "$$self{common_name}.iprscan.stats");
    return \@provides;
}

sub run_iprscan
{
    my ($self, $path, $lock_file) = @_;

    # create tmp directory for results
    my $dir = $path . '/_iprscan';
    Utils::create_dir($dir);
    
    # run iprscan on chunked sequences on LSF
    #my $chunks = get_chunk_number($self, $path);
    #my $iprscan_cmd = qq($$self{iprscan_exec} -cli -verbose -format raw -iprlookup -goterms -nocrc -email ap12\@sanger.ac.uk -i $path/$$self{seq_chunks_path}/$$self{lc_common_name}_cds_\$LSB_JOBINDEX.pep -o $$self{lc_common_name}_cds_\$LSB_JOBINDEX.iprscan);
    #LSF::run_array($lock_file, $dir, "_$$self{lc_common_name}_iprscan", $chunks, {bsub_opts=>$$self{bsub_long_opts}}, $iprscan_cmd);

    # run iprscan on entire sequence on LSF
    # dynamic script to be run by LSF
    open(my $fh,'>', "$path/_iprscan.pl") or Utils::error("$path/_iprscan.pl: $!");
    print $fh
qq[
use strict;
use warnings;
use Utils;

# run iprscan
Utils::CMD("$$self{iprscan_exec} -cli -verbose -format raw -iprlookup -goterms -nocrc -email ap12\\\@sanger.ac.uk -i $$self{pep} -o $$self{common_name}.iprscan");
if ( ! -s "$$self{common_name}.iprscan" ) { 
    Utils::error("The command ended with an error:\\n\\t$$self{iprscan_exec} -cli -verbose -format raw -iprlookup -goterms -nocrc -email ap12\\\@sanger.ac.uk -i $$self{pep} -o $$self{common_name}.iprscan\\n");
} else {
    # Convert iprscan results into EMBL file
    Utils::CMD("python $$self{iprscan2embl_exec} -i $$self{common_name}.iprscan -o $$self{common_name}.iprscan.embl -s $$self{common_name}.iprscan.stats -g $$self{go_map} -m $$self{seqids} -e $$self{embl}");
    if ( ! -s "$$self{common_name}.iprscan.embl" ) { 
        Utils::error("The command ended with an error:\\n\\tpython $$self{trnascan2tab_exec} -i $$self{common_name}.trnascan -o $$self{common_name}.trnascan.tab\\n");
    }

    # Tidy-up
    #unlink("$$self{common_name}.iprscan");
}
];
    close($fh);
    LSF::run($lock_file, $path, "_$$self{common_name}_iprscan", {bsub_opts=>$$self{bsub_long_opts}}, qq[perl -w _iprscan.pl]);

    return $$self{'No'};
}


### ---------------------------------------------------------------------------
### run_blastp
### ---------------------------------------------------------------------------
sub run_blastp_requires
{
    my ($self) = @_;
    my @requires;
    push(@requires, "$$self{seq_chunks_path}");
    return \@requires;
}

sub run_blastp_provides
{
    my ($self) = @_;
    my @provides;
    push(@provides, "blastp.done");
    return \@provides;
}

sub run_blastp
{
    my ($self, $path, $lock_file) = @_;

    # The big blastp file already exists
    if ( -e "$path/$$self{common_name}.blastp.tab.gz" )
    {
        Utils::CMD("touch $path/blastp.done");
        return;
    }

    # create tmp directory for results
    my $dir = $path . '/_blastp';
    Utils::create_dir($dir);

    # Because this subroutine returns as if it has already finished, a custom jids_file must
    # be used: Pipeline.pm will delete the $lock_file.
    my $jids_file = "$path/$$self{prefix}blastp_chunks.jid";
    my $status = LSF::is_job_running($jids_file);
    if ( $status&$LSF::Running ) { return; }
    if ( $status&$LSF::Error ) { $self->warn("Some jobs failed: $jids_file\n"); }

    # run blastp on chunked sequences on LSF and format results into EMBL feature table
    my $chunks = get_chunk_number($self, $path);
    my $blastp_cmd = qq($$self{blastall_exec} $$self{blastp_opts} -i $path/$$self{seq_chunks_path}/$$self{common_name}_\$LSB_JOBINDEX.pep | $$self{blast2tab_exec} -t -o $$self{common_name}_\$LSB_JOBINDEX.blastp);
    LSF::run_array($jids_file, $dir, "_$$self{common_name}_blastp", $chunks, {bsub_opts=>$$self{bsub_opts}}, $blastp_cmd);

    # concat blast results on LSF with dependency on previous job
    my $concat_cmd = "find $dir -name \"$$self{common_name}_*.blastp.tab\" | xargs cat | sort >> $$self{common_name}.blastp.tab";
    my $zip_cmd = "gzip $$self{common_name}.blastp.tab";
    #my $tidyup_cmd = "rm -rf $blastxdir";
    my $tidyup_cmd = "";
    my $res_cmd = $concat_cmd . " ; " . $zip_cmd . " ; " . $tidyup_cmd;
    LSF::run_dependency($jids_file, $path, "_$$self{common_name}_blastp",  "_$$self{common_name}_blastpres", {bsub_opts=>$$self{bsub_opts}}, $res_cmd);

    return $$self{'Yes'};
}


### ---------------------------------------------------------------------------
### run_signalp
### ---------------------------------------------------------------------------
sub run_signalp_requires
{
    my ($self) = @_;
    my @requires;
    push(@requires, "$$self{seq_chunks_path}");
    return \@requires;
}

sub run_signalp_provides
{
    my ($self) = @_;
    my @provides;
    push(@provides, "signalp.done");
    return \@provides;
}

sub run_signalp
{
    my ($self, $path, $lock_file) = @_;

    # The signalp file already exists
    if ( -e "$path/$$self{common_name}.signalp.tab" )
    {
        Utils::CMD("touch $path/signalp.done");
        return;
    }

    # create tmp directory for results
    my $dir = $path . '/_signalp';
    Utils::create_dir($dir);
    
    # Because this subroutine returns as if it has already finished, a custom jids_file must
    # be used: Pipeline.pm will delete the $lock_file.
    my $jids_file = "$path/$$self{prefix}signalp_chunks.jid";
    my $status = LSF::is_job_running($jids_file);
    if ( $status&$LSF::Running ) { return; }
    if ( $status&$LSF::Error ) { $self->warn("Some jobs failed: $jids_file\n"); }

    # run signalp on chunked sequences on LSF
    my $chunks = get_chunk_number($self, $path);
    my $signalp_cmd = qq($$self{signalp_exec} -t $$self{signalp_type} -trunc 70 -f summary -m hmm $path/$$self{seq_chunks_path}/$$self{common_name}_\$LSB_JOBINDEX.pep > $$self{common_name}_\$LSB_JOBINDEX.signalp);
    LSF::run_array($jids_file, $dir, "_$$self{common_name}_signalp", $chunks, {bsub_opts=>$$self{bsub_small_opts}}, $signalp_cmd);

    # concat signalp results on LSF with dependency on previous job
    #my $concat_cmd = "";
    #my $tidyup_cmd = "";
    #my $res_cmd = $concat_cmd . " ; " . $tidyup_cmd;
    #LSF::run_dependency($jids_file, $path, "_$$self{common_name}_signalp",  "_$$self{common_name}_signalpres", {bsub_opts=>$$self{bsub_opts}}, $res_cmd);

    return $$self{'Yes'};
}


### ---------------------------------------------------------------------------
### run_tmhmm
### ---------------------------------------------------------------------------
sub run_tmhmm_requires
{
    my ($self) = @_;
    my @requires;
    push(@requires, "$$self{embl}");
    push(@requires, "$$self{seqids}");
    push(@requires, "$$self{pep}");
    return \@requires;
}

sub run_tmhmm_provides
{
    my ($self) = @_;
    my @provides;
    push(@provides, "$$self{common_name}.tmhmm.embl");
    return \@provides;
}

sub run_tmhmm
{
    my ($self, $path, $lock_file) = @_;

    # dynamic script to be run by LSF
    open(my $fh,'>', "$path/_tmhmm.pl") or Utils::error("$path/_tmhmm.pl: $!");
    print $fh
qq[
use strict;
use warnings;
use Utils;

# run tmhmm
Utils::CMD("$$self{tmhmm_exec} $$self{pep} > $$self{common_name}.tmhmm");
if ( ! -s "$$self{common_name}.tmhmm" ) { 
    Utils::error("The command ended with an error:\\n\\t$$self{tmhmm_exec} $$self{pep} > $$self{common_name}.tmhmm\\n");
} else {
    # Convert tmhmm results into EMBL file
    Utils::CMD("python $$self{tmhmm2embl_exec} -i $$self{common_name}.tmhmm -o $$self{common_name}.tmhmm.embl -e $$self{embl} -m $$self{seqids}");
    if ( ! -s "$$self{common_name}.tmhmm.embl" ) { 
        Utils::error("The command ended with an error:\\n\\tpython $$self{tmhmm2embl_exec} -i $$self{common_name}.tmhmm -o $$self{common_name}.tmhmm.embl -e $$self{embl} -m $$self{seqids}\\n");
    }
    
    # Tidy-up
    unlink("$$self{common_name}.tmhmm")

}
];
    close($fh);
    LSF::run($lock_file, $path, "_$$self{common_name}_tmhmm", $self, qq[perl -w _tmhmm.pl]);

    return $$self{'No'};
}


### ---------------------------------------------------------------------------
### run_pfamscan
### ---------------------------------------------------------------------------
sub run_pfamscan_requires
{
    my ($self) = @_;
    my @requires;
    push(@requires, "$$self{pep}");
    push(@requires, "$$self{embl}");
    push(@requires, "$$self{seqids}");
    return \@requires;
}

sub run_pfamscan_provides
{
    my ($self) = @_;
    my @provides;
    push(@provides, "$$self{common_name}.pfamscan.embl");
    push(@provides, "$$self{common_name}.pfamscan.stats");
    return \@provides;
}

sub run_pfamscan
{
    my ($self, $path, $lock_file) = @_;

    # dynamic script to be run by LSF
    open(my $fh,'>', "$path/_pfamscan.pl") or Utils::error("$path/_pfamscan.pl: $!");
    print $fh
qq[
use strict;
use warnings;
use Utils;

# run pfamscan
Utils::CMD("$$self{pfamscan_exec} -fasta $$self{pep} -dir $$self{pfam_dir} > $$self{common_name}.pfamscan");
if ( ! -s "$$self{common_name}.pfamscan" ) { 
    Utils::error("The command ended with an error:\\n\\t$$self{pfamscan_exec} -fasta $$self{pep} -dir $$self{pfam_dir} > $$self{common_name}.pfamscan\\n");
} else {
    # Convert pfamscan results into EMBL file
    Utils::CMD("python $$self{pfam2embl_exec} -i $$self{common_name}.pfamscan -e $$self{embl} -o $$self{common_name}.pfamscan.embl -s $$self{common_name}.pfamscan.stats -p $$self{pfam2go} -g $$self{go_map} -m $$self{seqids}");
    if ( ! -s "$$self{common_name}.pfamscan.embl" ) { 
        Utils::error("The command ended with an error:\\n\\tpython $$self{pfam2embl_exec} -i $$self{common_name}.pfamscan -e $$self{embl} -o $$self{common_name}.pfamscan.embl -s $$self{common_name}.pfamscan.stats -p $$self{pfam2go} -g $$self{go_map} -m $$self{seqids}\\n");
    }

    # Tidy-up
    #unlink("$$self{common_name}.pfamscan")
}
];
    close($fh);
    LSF::run($lock_file, $path, "_$$self{common_name}_pfamscan", $self, qq[perl -w _pfamscan.pl]);

    return $$self{'No'};
}


### ---------------------------------------------------------------------------
### utility methods
### ---------------------------------------------------------------------------
sub get_chunk_number
{
    my ($self, $path) = @_;
    
    my @files = <$path/$$self{seq_chunks_path}/$$self{common_name}_*.pep>;
    my $count = @files;
    return $count;
}


### ---------------------------------------------------------------------------
### Debugging and error reporting
### ---------------------------------------------------------------------------
sub warn
{
    my ($self,@msg) = @_;
    my $msg = join('',@msg);
    if ($self->verbose > 0) 
    {
        print STDERR $msg;
    }
    $self->log($msg);
}

sub debug
{
    my ($self,@msg) = @_;
    if ($self->verbose > 0) 
    {
        my $msg = join('',@msg);
        print STDERR $msg;
        $self->log($msg);
    }
}

sub throw
{
    my ($self,@msg) = @_;
    Utils::error(@msg);
}

sub log
{
    my ($self,@msg) = @_;

    my $msg_str = join('',@msg);
    my $status  = open(my $fh,'>>',$self->log_file);
    if ( !$status ) 
    {
        print STDERR $msg_str;
    }
    else 
    { 
        print $fh $msg_str; 
    }
    if ( $fh ) { close($fh); }
}

1;

