#!/usr/bin/perl

use strict;
use warnings;

use Compress::Zlib;
use English qw(-no_match_vars);
use Test::More;
use Test::Exception;

use FusionInventory::Agent::HTTP::Client::GLPI;

plan tests => 2;

my $client = FusionInventory::Agent::HTTP::Client::GLPI->new();

my $data = "this is a test";
is(
    $client->_uncompressZlib($client->_compressZlib($data)),
    $data,
    'round-trip compression with Compress::Zlib'
);

SKIP: {
    skip "gzip is not available under Windows", 1 if $OSNAME eq 'MSWin32';
    is(
        $client->_uncompressGzip($client->_compressGzip($data)),
        $data,
        'round-trip compression with Gzip'
    );
}
