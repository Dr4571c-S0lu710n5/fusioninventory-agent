package FusionInventory::Agent::Task::Inventory::Generic::Softwares::Snap;

use strict;
use warnings;

use parent 'FusionInventory::Agent::Task::Inventory::Module';

use English qw(-no_match_vars);
use File::stat;
use YAML::Tiny;

use FusionInventory::Agent::Tools;

sub isEnabled {
    return canRun('snap');
}

sub doInventory {
    my (%params) = @_;

    my $inventory = $params{inventory};
    my $logger    = $params{logger};

    my $packages = _getPackagesList(
        logger  => $logger,
        command => 'snap list --color never',
    );
    return unless $packages;

    foreach my $snap (@{$packages}) {
        _getPackagesInfo(
            logger  => $logger,
            snap    => $snap,
            command => 'snap info --color never --abs-time '.$snap->{NAME},
        );
        $inventory->addEntry(
            section => 'SOFTWARES',
            entry   => $snap
        );
    }
}

sub _getPackagesList {
    my (%params) = @_;

    my $handle = getFileHandle(%params);
    return unless $handle;

    my @packages;
    while (my $line = <$handle>) {
        chomp $line;
        my @infos = split(/\s+/, $line)
            or next;

        # Skip header
        next if $infos[0] eq 'Name' && $infos[1] eq 'Version';

        # Skip base and snapd
        next if $infos[5] && $infos[5] =~ /^base|core|snapd$/;

        my $snap = {
            NAME            => $infos[0],
            VERSION         => $infos[1],
            FROM            => 'snap'
        };

        my $folder = "/snap/".$snap->{NAME};
        # Don't check install date during unittest
        if (!$params{file} && -d $folder) {
            my $st = stat($folder);
            my ($year, $month, $day) = (localtime($st->mtime))[5, 4, 3];
            $snap->{INSTALLDATE}  = sprintf(
                "%02d/%02d/%04d", $day, $month + 1, $year + 1900
            );
        }

        push @packages, $snap;
    }
    close $handle;

    return \@packages;
}

sub _getPackagesInfo {
    my (%params) = @_;

    # snap info command may wrongly output some long infos
    local $ENV{COLUMNS} = 100;

    my $snap = delete $params{snap};
    my $lines = getAllLines(%params)
        or return;

    my ($yaml, $infos);
    eval {
        $yaml  = YAML::Tiny->read_string($lines);
        $infos = $yaml->[0];
    };

    if ($EVAL_ERROR && $params{logger}) {
        $params{logger}->warning("Wrong $snap->{NAME} snap info output: $EVAL_ERROR");
        $params{logger}->info("Please report snap info output:\n$lines");
    }

    return unless $infos && $infos->{name};

    $snap->{PUBLISHER} = $infos->{publisher};
    # Cleanup publisher from 'starred' if verified
    $snap->{PUBLISHER} =~ s/[*]$//;
    $snap->{COMMENTS}  = $infos->{summary};
    $snap->{HELPLINK}  = $infos->{contact};

    # Find installed size
    my ($size) = $infos->{installed} =~ /\(.*\)\s+(\d+\S+)/;
    $snap->{FILESIZE} = getCanonicalSize($size, 1024) * 1048576
        if $size;
}

1;
