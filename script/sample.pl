#!/usr/bin/perl
use strict;
use TailF::Twitter::StreamServer;

my $server = TailF::Twitter::StreamServer->new_with_options();
$server->run();
