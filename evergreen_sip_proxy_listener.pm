#!/usr/bin/perl
#

package evergreen_sip_proxy_listener;

use DateTime;
use utf8;
use IO::Socket::INET;
use IO::Select;
use Data::Dumper;
use evergreen_sip_client;


our $lastdt;


sub new
{
    my $class = shift;
    my $self = 
	{
        connection => shift,
        log => shift,
        conf => shift,
        client_socket => shift,
        sipclient => shift,
        title => shift,
        logincache => ''
	};
    # print "Starting evergreen_sip_proxy_listener instance with this config\n";
	# print Dumper($self->{conf});
	bless $self, $class;
    return $self;
}

sub socketlisten
{
    my $self = @_[0];
    my $alldata = '';
    
    # Make sure that the socket is flushing
    # print "flush: ".$self->{connection}->autoflush."\n";
    # print "Listening\n";
    
    # execution will stop here until the NEW client initiates a connection
    # if we already have a client, then we move onto recv
    my $newClient = 0;
    $self->{log}->addLogLine("SIPLISTENER Thread[$$] Accepting new connections on blank socket") if  !$self->{client_socket};
    $newClient = 1 if  !$self->{client_socket};
    $self->{client_socket} = $self->{connection}->accept() if !$self->{client_socket};
    my $socket = $self->{client_socket};
    binmode ($socket,":utf8");
    $self->{log}->addLogLine("SIPLISTENER Thread[$$] moving into recv");
    if($newClient)
    {
        my $client_address = $self->{client_socket}->peerhost();
        my $client_port = $self->{client_socket}->peerport();
        $self->{log}->addLogLine("SIPLISTENER Thread[$$] connection from $client_address:$client_port");
    }
    my $data='';
    
    $lastdt = DateTime->now(time_zone => "local");
    my $select = new IO::Select();
    $select->add($socket);
    my $skipdurationcheck = 1;
    while ( 1 )
    {
        $| = 1;
        $self->{connection}->autoflush;
        # print "flush: ".$self->{connection}->autoflush."\n";
        if($select->can_read(.1))
        {
            # execution will pause here as long as there is a socket. it will wait for data
            $socket->recv($data, 1024);
            if($data ne '')
            {
                $lastdt = DateTime->now(time_zone => "local");
                $skipdurationcheck = 1;
                $alldata.=$data;
                $self->{log}->addLogLine("SIPLISTENER Thread[$$] alldata = $alldata");
                if(length($alldata) > 0)
                {
                    if (  (ord(substr($alldata,-1)) eq "10")  || (ord(substr($alldata,-1)) eq "13") )
                    {
                        $self->{log}->addLogLine("SIPLISTENER Thread[$$] return carrage detected");
                        last;
                    }
                }
            }
            else
            {
                $self->{log}->addLogLine("SIPLISTENER Thread[$$] Data was blank");
                $skipdurationcheck = 0;
            }
        }
        if(!is_healthy($self)) {last;}
        if( !duration($self, $self->{conf}{client_timeout}) && !$skipdurationcheck )
        {
            # The while loop would have looped only because the socket isn't really there. 
            # The timer will prevent this from never ending
            # We're dead, let's seppuku
            $self->{log}->addLogLine("SIPLISTENER Thread[$$] seppeku");
            breakdown($self);
            die "Lost client";
        }
    }
    
    $self->{log}->addLogLine("SIPLISTENER Thread[$$] - $client_address:$client_port $data");
    return $alldata;
}

sub continueconversation
{
    my $self = shift;
    my $data = shift;
    while(is_healthy($self))  # loop forever, it will die when connections die
    {   
        # Catch the login attempt and fake the response
        my $response = '';
        if( $data =~ m/^93/ )
        {
            $self->{logincache} = $data;
            $response = setupclient($self, 1);
            $self->{log}->addLogLine("SIPLISTENER Thread[$$] Reset login with Evergreen - got '$response'");
            $self->{client_socket}->send($response);
        }
        else
        {
            # We have a real information request, need to proxy it
            setupclient($self);
            # print "Sending to external server '$data' \n";
            # my $response = "roger that\r"; #
            $response = $self->{sipclient}->send($data);
        }
        if($response eq "NOT CONNECTED\r")
        {
            setupclient($self, 1);
            $response = $self->{sipclient}->send($data);
            $self->{log}->addLogLine("SIPLISTENER Thread[$$] We had an issue with the Evergreen SIP server. Created a new connection");
        }
        $self->{log}->addLogLine("SIPLISTENER Thread[$$] responding to our client with '$response'");
        $self->{client_socket}->send($response);
        $data = socketlisten($self);
    }
    breakdown($self);
    die "Lost connection to ".$self->{client_socket}->peerport();
}

sub setupclient
{
    my $self = shift;
    my $reset = shift;
    # print Dumper($self->{conf});
    # connection is down or never existed
    if( (!$self->{sipclient}) or (!$self->{sipclient}->is_healthy) or $reset)
    {
        $self->{log}->addLogLine("SIPLISTENER Thread[$$] setting up new client connection");
        $self->{log}->addLogLine("SIPLISTENER Thread[$$] ".$self->{conf}{server});
        $self->{log}->addLogLine("SIPLISTENER Thread[$$] ".$self->{conf}{port});
        $self->{log}->addLogLine("SIPLISTENER Thread[$$] ".$self->{conf}{evergreen_timeout});
        
        # Call DESTROY
        $self->{sipclient}->breakdown() if $self->{sipclient};
        undef $self->{sipclient};
        $self->{sipclient} = new evergreen_sip_client(
        $self->{conf}{server},
        $self->{conf}{port},
        $self->{conf}{evergreen_timeout},
        $self->{log}
        );
        my $healthy =  $self->{sipclient}->start();
        $self->{log}->addLogLine("SIPLISTENER Thread[$$] Healthy = $healthy");
        return $healthy if !$healthy;
        return $self->{sipclient}->send($self->{logincache});
        breakdown($self);
        die "Unable to connect to ".$self->{conf}{server};
    }
    else
    {
        $self->{log}->addLogLine("SIPLISTENER Thread[$$] proxied server connection is still active");
    }
}

sub is_healthy
{
    my $self = shift;
    # print Dumper($self->{connection});
    return !$self->{connection}->error;
}

sub duration
{
    my $self = shift;
    my $timeout = shift;
    my $afterProcess = DateTime->now(time_zone => "local");
    my $difference = $afterProcess - $lastdt;
    my $format = DateTime::Format::Duration->new(pattern => '%M:%S');
    my $duration =  $format->format_duration($difference);
    my @s = split(/:/,$duration);
    my $minutes = @s[0]+0;
    my $seconds = @s[1]+0;
    my $seconds = ($minutes*60) + $seconds;
    my $ret = ($timeout > $seconds);
    return $ret;
}

sub breakdown
{
    my $self = shift;
    $self->{log}->addLogLine("SIPLISTENER Thread[$$] SIP PROXY LISTENER DESTROY");
    $self->{client_socket}->close();
    $self->{sipclient}->breakdown();
    shutdown($self->{client_socket}, 2);
}
 
sub DESTROY
{
	my $self = shift;
    breakdown($self);
    undef $self->{client_socket};
    undef $self->{sipclient};
	undef $self;
}

1;
