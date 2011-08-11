=head1 NAME

Pathogens::Annotate::Rnammer

=head1 SYNOPSIS

=cut

package Pathogens::Annotate::Rnammer;
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
        'name'     => 'run_rnammer',
        'action'   => \&run_rnammer,
        'requires' => \&run_rnammer_requires, 
        'provides' => \&run_rnammer_provides,
    },
);

our $options = 
{
    # Executables
    'rnammer_exec'         => '/nfs/users/nfs_a/ap12/lib/rnammer-1.2/rnammer',
    'rnammer2tab_exec'     => '/nfs/users/nfs_a/ap12/genlibpy/genepy/convertors/rnammer2tab.py',

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
    $self->{lc_common_name} = lc($$self{common_name});

    # set sequence
    $self->{sequence} = 'sequence.fna';

    return $self;
}


### ---------------------------------------------------------------------------
### run_rnammer
### ---------------------------------------------------------------------------
sub run_rnammer_requires
{
    my ($self) = @_;
    my @requires;
    push(@requires, "$$self{fasta}");
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

    # create symlink to fasta file
    Utils::relative_symlink($$self{fasta}, $path . '/' . $$self{sequence}); 

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
    Utils::CMD("python $$self{rnammer2tab_exec} -i $$self{common_name}.rnammer.gff -o $$self{common_name}.rnammer.tab");
    if ( ! -s "$$self{common_name}.rnammer.tab" ) { 
        Utils::error("The command ended with an error:\\n\\tpython $$self{rnammer2tab_exec} -i $$self{common_name}.rnammer.gff -o $$self{common_name}.rnammer.tab\\n");
    }

    # Tidy-up
    unlink("$$self{common_name}.rnammer.gff");
}
];
    close($fh);
    LSF::run($lock_file, $path, "_$$self{common_name}_rnammer", {bsub_opts=>$$self{bsub_opts}}, "perl -w _rnammer.pl");

    return $$self{'No'};
}

1;

