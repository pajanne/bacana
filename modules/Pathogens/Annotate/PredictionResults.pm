=head1 NAME

Pathogens::Annotate::PredictionResults

=head1 SYNOPSIS

Pipeline step for merging results of gene prediction steps, inherits from VertRes::Pipelines.

=cut

package Pathogens::Annotate::PredictionResults;
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
);

our $options = 
{
    # Executables
    'merger_exec'          => 'gfind_merger.py',

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
    push(@provides, "$$self{embl}");
    return \@provides;
}

sub run_cds_merger
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
Utils::CMD("$$self{merger_exec} -s $$self{fasta} -p ../prodigal/$$self{common_name}.prodigal.tab -g ../glimmer/$$self{common_name}.g3.tab -o $$self{embl} -n $$self{common_name} -l XXX", {'verbose'=>1, 'time'=>1});

];
    close($fh);
    LSF::run($lock_file, $path, "_$$self{common_name}_merger", $self, qq[perl -w _merger.pl]);

    return $$self{'No'};
}


1;

