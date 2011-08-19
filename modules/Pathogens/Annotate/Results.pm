=head1 NAME

Pathogens::Annotate::Results

=head1 SYNOPSIS

Pipeline step for merging results of gene prediction and annotation tools, inherits from VertRes::Pipelines.

=cut

package Pathogens::Annotate::Results;
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
        'name'     => 'run_cds_merger',
        'action'   => \&run_cds_merger,
        'requires' => \&run_cds_merger_requires, 
        'provides' => \&run_cds_merger_provides,
    },
    {
        'name'     => 'run_prediction_merger',
        'action'   => \&run_prediction_merger,
        'requires' => \&run_prediction_merger_requires, 
        'provides' => \&run_prediction_merger_provides,
    },
);

our $options = 
{
    # Executables
    'merger_exec'          => 'gfind_merger.py',
    'converter_exec'       => 'addft2embl.py',

    # LSF options
    'bsub_opts'            => '-q normal',
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

    # set embl result file
    $self->{embl} = $$self{common_name} . '.embl';

    return $self;
}



### ---------------------------------------------------------------------------
### run_cds_merger
### ---------------------------------------------------------------------------
sub run_cds_merger_requires
{
    my ($self) = @_;
    my @requires;
    push(@requires, "$$self{fasta}");
    push(@requires, "../prodigal/$$self{common_name}.prodigal.tab");
    push(@requires, "../glimmer/$$self{common_name}.g3.tab");
    return \@requires;
}

sub run_cds_merger_provides
{
    my ($self) = @_;
    my @provides;
    push(@provides, "$$self{common_name}_cds.embl");
    return \@provides;
}

sub run_cds_merger
{
    my ($self, $path, $lock_file) = @_;

    # dynamic script to be run by LSF
    open(my $fh,'>', "$path/_cds_merger.pl") or Utils::error("$path/_cds_merger.pl: $!");
    print $fh
qq[
use strict;
use warnings;
use Utils;

# run merger to create EMBL file
Utils::CMD("$$self{merger_exec} -s $$self{fasta} -p ../prodigal/$$self{common_name}.prodigal.tab -g ../glimmer/$$self{common_name}.g3.tab -o $$self{common_name}_cds.embl -n $$self{common_name} -l XXX", {'verbose'=>1, 'time'=>1});

];
    close($fh);
    LSF::run($lock_file, $path, "_$$self{common_name}_cds_merger", $self, qq[perl -w _cds_merger.pl]);

    return $$self{'No'};
}

### ---------------------------------------------------------------------------
### run_prediction_merger
### ---------------------------------------------------------------------------
sub run_prediction_merger_requires
{
    my ($self) = @_;
    my @requires;
    push(@requires, "$$self{common_name}_cds.embl");
    push(@requires, "../rnammer/$$self{common_name}.rnammer.tab");
    push(@requires, "../trnascan/$$self{common_name}.trnascan.tab");
    push(@requires, "../repeatscout/$$self{common_name}.repeatscout.tab");
    push(@requires, "../alienhunter/$$self{common_name}.alienhunter.tab");
    return \@requires;
}

sub run_prediction_merger_provides
{
    my ($self) = @_;
    my @provides;
    push(@provides, "$$self{embl}");
    return \@provides;
}

sub run_prediction_merger
{
    my ($self, $path, $lock_file) = @_;

    # dynamic script to be run by LSF
    open(my $fh,'>', "$path/_prediction_merger.pl") or Utils::error("$path/_prediction_merger.pl: $!");
    print $fh
qq[
use strict;
use warnings;
use Utils;

# run converter to create EMBL file
Utils::CMD("$$self{converter_exec} -i $$self{common_name}_cds.embl                  -t ../rnammer/$$self{common_name}.rnammer.tab     -o  $$self{common_name}_cds_rrna.embl", {'verbose'=>1, 'time'=>1});
Utils::CMD("$$self{converter_exec} -i $$self{common_name}_cds_rrna.embl             -t ../rnammer/$$self{common_name}.trnascan.tab    -o  $$self{common_name}_cds_rrna_trna.embl", {'verbose'=>1, 'time'=>1});
Utils::CMD("$$self{converter_exec} -i $$self{common_name}_cds_rrna_trna.embl        -t ../rnammer/$$self{common_name}.repeatscout.tab -o  $$self{common_name}_cds_rrna_trna_repeat.embl", {'verbose'=>1, 'time'=>1});
Utils::CMD("$$self{converter_exec} -i $$self{common_name}_cds_rrna_trna_repeat.embl -t ../rnammer/$$self{common_name}.alienhunter.tab -o  $$self{common_name}.embl", {'verbose'=>1, 'time'=>1});

# tidy-up
unlink("$$self{common_name}_cds_rrna.embl");
unlink("$$self{common_name}_cds_rrna_trna.embl");
unlink("$$self{common_name}_cds_rrna_trna_repeat.embl");


];
    close($fh);
    LSF::run($lock_file, $path, "_$$self{common_name}_prediction_merger", $self, qq[perl -w _prediction_merger.pl]);

    return $$self{'No'};
}


1;

