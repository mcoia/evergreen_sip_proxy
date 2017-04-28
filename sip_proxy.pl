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
    
    
    # my $sipclient = new evergreen_sip_client(
        # $conf{server},
        # $conf{port},
        # $conf{username},
        # $conf{password},
        # $conf{institution},
        # $log
        # );
        # $sipclient->start();
        # exit;
     # my $select=new IO::Select();
     # my $socket = undef;
    # # auto-flush on socket
    # $| = 1;
    # $socket->close() if($socket);
    # undef $socket;
    
    # # create a connecting socket
    # $socket = new IO::Socket::INET (
        # PeerHost => $conf{server},
        # PeerPort => $conf->{port},
        # Proto => 'tcp',
        # Type     => SOCK_STREAM
    # );
    # die "cannot connect to the server $!\n" unless $socket;
    # #binmode($socket, ":utf8");
    # print Dumper($socket->connected);
    # print "connected to the server\n";
    
    # $select->add($socket);
    
    # print "sipclient:\n";
    # print "sock->connected  : ", ($socket->connected  || ''), "\n";
    # print "sock->protocol   : ", ($socket->protocol   || ''), "\n";
    # print "sock->sockdomain : ", ($socket->sockdomain || ''), "\n";
    # print "sock->socktype   : ", ($socket->socktype   || ''), "\n";
    # print "sock->timeout    : ", ($socket->timeout    || ''), "\n";
    # print "\n";
    
    # $socket->autoflush;
    
    
    # # Evergreen SIP Login
    # my $req = '9300CN'.$conf->{username}.'|CO'.$conf->{password}.'|CP'.$conf->{institution}."\r";
    # print $socket $req;
    # # my $size = $socket->send($req);
    # # print "sent data of length $size\n";
    
    # # receive a response of up to 1024 characters from server
    # my $response = "";
    
    # while( recv ($socket,$response,1024,0) )
    # {
        # $response.=$_;
        # print $response;
        # sleep 1;
    # }
    # # $socket->recv($response, 1024);
    # my $patronstatus = "6300120140915 084647 AOmobius|AA9300822470|AC|AD\r";
     
    # print "received response: $response\n";
    
    # print "closed and now the variable is\n";
    # print Dumper($select);
    
    
    # # open(my $fh, "+>", $socket);
    # print $socket $patronstatus;
    # while( recv ($socket,$response,1024,0) )
    # {
        # $response.=$_;
        # print $response;
        # sleep 1;
    # }
    # # close($fh);
   
    # # $socket->accept();
    # # while(1)
    # # {   
        # # if($select->can_write(9))
        # # {
            
            # # print "Sending $patronstatus\n";
            # # local $@;
            # # eval
            # # {
                # # my $size = $socket->send($patronstatus);
            # # };
            # # print "error". $@."\n" if $@;
            # # print "finished\n";
            # # # shutdown($socket, 1);
            # # last;
        # # }
        # # else {print "never wrote\n"; last;}
    # # }
    
    # print "sent: $patronstatus\n";
    # # Stop writing
    # # shutdown($socket, 1);
    # while(!$select->can_read(1))
    # {
        # if($select->can_read(30))
        # {
            # $socket->recv($response, 1024);
        # }
        # else {print "never recv\n"; last;}
    # }
    
    # # Stop reading
    # # shutdown($socket, 0);
    # print "received response: $response\n";
    
    
    
    # exit;
    
    
my $server = new evergreen_sip_proxy_server("6001", $log, \%conf); 
$server->start(); 
    # my $serverThread = threads->create(sub { my $server = new new evergreen_sip_proxy_server("6001", $log, "go"); $server->start(); return $server; });
    # my @res1 = $serverThread->join();
    
    while(1)
    {
        # print Dumper(@res1);
        print "execution is at sip_proxy.pl\n";
        sleep 2;
    }
    
    
    $log->addLogLine(" ---------------- Script End ---------------- ");	
}


sub figureDateString
{
	my $daysback=@_[0];
	my $dt = DateTime->now;   # Stores current date and time as datetime object	
	my $target = $dt->subtract(days=>$daysback);
	my @ret=($target->ymd,$target->mdy);
	return \@ret;	
}

sub trim
{
	my $string = shift;
	$string =~ s/^\s+//;
	$string =~ s/\s+$//;
	return $string;
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
        print $line."\n";
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
 

exit;
