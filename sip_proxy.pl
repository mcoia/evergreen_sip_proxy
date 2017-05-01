#!/usr/bin/perl
use lib qw(../);
use strict; 
use Loghandler;
use Data::Dumper;
use utf8;
use DateTime;
use Getopt::Long;
use IO::Socket::INET;
use IO::Select;
use evergreen_sip_proxy_server;
use evergreen_sip_client;
use threads;

my $configFile=0;
our $debug=0;

GetOptions (
"configfile=s" => \$configFile,
"debug" => \$debug,
)
or die("Error in command line arguments\nYou can specify
--configfile configfilename (required)
--debug flag
\n");

if(! -e $configFile)
{
	print "I could not find the config file: $configFile\nYou can specify the path when executing this script --configfile configfilelocation\n";
	exit 0;
}

our $log;
our $conf = readConfFile($configFile);
our %conf;
    
if($conf)
{
    %conf = %{$conf};
    
    my $dt = DateTime->now(time_zone => "local"); 
    my $fdate = $dt->ymd; 
    my $ftime = $dt->hms;
    my $dateString = "$fdate $ftime";
    $log = new Loghandler($conf{"logfile"});
    $log->truncFile("");
    $log->addLogLine(" ---------------- Script Starting ---------------- ");
    
    
    my $server = new evergreen_sip_proxy_server($conf{"local_port"}, $log, \%conf);
    $server->start();
  
    $log->addLogLine(" ---------------- Script End ---------------- ");	
}

sub readConfFile
{
    my %ret = ();
    my $ret = \%ret;
    my $file = @_[0];

    my $confFile = new Loghandler($file);
    if(!$confFile->fileExists())
    {
        print "Config File does not exist\n";
        undef $confFile;
        return 0;
    }

    my @lines = @{ $confFile->readFile() };
    undef $confFile;

    foreach my $line (@lines)
    {
        $line =~ s/\n//;  #remove newline characters
        # print $line."\n";
        my $cur = trim($line);
        my $len = length($cur);
        if($len>0)
        {
            if(substr($cur,0,1)ne"#")
            {
                my ($Name, $Value) = split (/=/, $cur);
                $$ret{trim($Name)} = trim($Value);
            }
        }
    }

    return \%ret;
}

sub trim
{
	my $string = shift;
	$string =~ s/^\s+//;
	$string =~ s/\s+$//;
	return $string;
}

exit;
