=head1 NAME

Pathogens::Annotate::Prodigal

=head1 SYNOPSIS

Pipeline step for Prodigal, inherits from VertRes::Pipelines.

=cut

package Pathogens::Annotate::Prodigal;
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
        'name'     => 'run_prodigal',
        'action'   => \&run_prodigal,
        'requires' => \&run_prodigal_requires, 
        'provides' => \&run_prodigal_provides,
    },
);

our $options = 
{
    'prodigal_exec'        => '/software/pathogen/external/bin/prodigal',
    'prodigal2tab_exec'    => '/nfs/users/nfs_a/ap12/genlibpy/genepy/convertors/prodigal2tab.py',

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

    # set sequence
    $self->{sequence} = 'sequence.fna';

    return $self;
}


### ---------------------------------------------------------------------------
### run_prodigal
### ---------------------------------------------------------------------------
sub run_prodigal_requires
{
    my ($self) = @_;
    my @requires;
    push(@requires, "$$self{fasta}");
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

    # create symlink to fasta file
    Utils::relative_symlink($$self{fasta}, $path . '/' . $$self{sequence}); 

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
    Utils::CMD("python $$self{prodigal2tab_exec} -i $$self{common_name}.prodigal -o $$self{common_name}.prodigal.tab");
    if ( ! -s "$$self{common_name}.prodigal.tab" ) { 
        Utils::error("The command ended with an error:\\n\\tpython $$self{prodigal2tab_exec} -i $$self{common_name}.prodigal -o $$self{common_name}.prodigal.tab\\n");
    }

    # Tidy-up
    unlink("$$self{common_name}.prodigal");
}
];
    close($fh);
    LSF::run($lock_file, $path, "_$$self{common_name}_prodigal", $self, "perl -w _prodigal.pl");

    return $$self{'No'};
}


1;

