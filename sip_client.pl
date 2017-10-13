#!/usr/bin/perl
use lib qw(../);
use strict; 
use Loghandler;
use Data::Dumper;
use utf8;
use DateTime;
use Getopt::Long;
use evergreen_sip_client;
    
    
    my $log = new Loghandler("/changeme/sipclientlog.log");
    $log->truncFile("");
    my $sipclient = new evergreen_sip_client(
        '127.0.0.1',
        '6001',
        2,
        $log
        );
        $sipclient->start();
        
   
    my $input = '';
    my $response = '';
    while ($sipclient->is_healthy())
    {
        $response = '';
        print "Enter command:\n";
        my $input = <STDIN>;
        $input =~ s/\n/\r/g;
        $response = $sipclient->send($input);
        print "'$response'\n";
    }
   exit;
