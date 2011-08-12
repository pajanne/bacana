=head1 NAME

Pathogens::Annotate::Trnascan

=head1 SYNOPSIS

=cut

package Pathogens::Annotate::Trnascan;
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
        'name'     => 'run_trnascan',
        'action'   => \&run_trnascan,
        'requires' => \&run_trnascan_requires, 
        'provides' => \&run_trnascan_provides,
    },
);

our $options = 
{
    # Executables
    'trnascan_exec'        => '/software/pathogen/external/bin/tRNAscan-SE',
    'trnascan2tab_exec'    => '/nfs/users/nfs_a/ap12/genlibpy/genepy/convertors/trnascan2tab.py',

    # LSF options
    'bsub_opts'            => '-q long',
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

    return $self;
}


### ---------------------------------------------------------------------------
### run_trnascan
### ---------------------------------------------------------------------------
sub run_trnascan_requires
{
    my ($self) = @_;
    my @requires;
    push(@requires, "$$self{fasta}");
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
Utils::CMD("$$self{trnascan_exec} -P -o $$self{common_name}.trnascan -q -b -Q -C $$self{fasta} > _trnascan_cmd.log", {'verbose'=>1, 'time'=>1});

# if no result file, create one
if ( ! -s "$$self{common_name}.trnascan" ) { 
    Utils::CMD("touch $$self{common_name}.trnascan");
}

# convert trnascan results into EMBL feature table
Utils::CMD("python $$self{trnascan2tab_exec} -i $$self{common_name}.trnascan -o $$self{common_name}.trnascan.tab", {'verbose'=>1, 'time'=>1});

# Tidy-up
unlink("$$self{common_name}.trnascan");

];
    close($fh);
    LSF::run($lock_file, $path, "_trnascan_bsub", {bsub_opts=>$$self{bsub_opts}}, "perl -w _trnascan.pl");

    return $$self{'No'};
}


1;

