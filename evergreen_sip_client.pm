#!/usr/bin/perl
#

package evergreen_sip_client;

use DateTime;
use utf8;
use IO::Socket::INET;
use IO::Select;
use Data::Dumper;
use DateTime::Format::Duration;

our $lastdt;

sub new
{
    my $class = shift;
    my $self = 
	{
		server => shift,
        port => shift,
        timeout => shift,
        log => shift,
        connection => shift,
        lastx => '',
        lastr => '',
        lastxdt => undef
	};
	
	bless $self, $class;
    return $self;
}


sub start
{
    my $self = @_[0];
    sipconnect($self);
    return 1 if is_healthy($self);
    return 0;
}

sub sipconnect
{
    my $self = @_[0];
    # auto-flush on socket
    $| = 1;
    $self->{connection}->close() if($self->{connection});
    undef $self->{connection};
    
    
    
    # create a connecting socket
    $self->{connection} = new IO::Socket::INET (
        PeerHost => $self->{server},
        PeerPort => $self->{port},
        Proto    => 'tcp',
        Type     => SOCK_STREAM
    );
    die "cannot connect to the server $!\n" unless $self->{connection};
    
    my $socket = $self->{connection};
    $socket->autoflush;
    binmode ($socket, ":utf8");
    
    # my $select = new IO::Select();
    # $select->add($socket);
    # sleep 2;
    # print "connected to the server\n";
    # print "sipclient:\n";
    # print "sock->connected  : ", ($self->{connection}->connected  || ''), "\n";
    # print "sock->protocol   : ", ($self->{connection}->protocol   || ''), "\n";
    # print "sock->sockdomain : ", ($self->{connection}->sockdomain || ''), "\n";
    # print "sock->socktype   : ", ($self->{connection}->socktype   || ''), "\n";
    # print "sock->timeout    : ", ($self->{connection}->timeout    || ''), "\n";
    # print "\n";
    
}

sub send
{
    my $self = shift;
    my $data = shift;
    return _send($self,$data);
}

sub _send
{
    my $self = shift;
    my $data = shift;
    
    while (!is_healthy($self))
    {
        print "We are not connected to the server, we are attempting to connect now\n";
        sipconnect($self);
    }
    
    my $socket = $self->{connection};
    $socket->autoflush;
    my $select = new IO::Select();
    $select->add($socket);
    if($select->can_write(.25) )
    {
        print "sipclient sending '$data'\n";
        $socket->send($data);
        $self->{lastx} = $data;
        $self->{lastxdt} = DateTime->now(time_zone => "local");
    }
    else
    {
        print "Unable to transmit\n";
        return 'NOT CONNECTED\r';
    }
    
    my $response = "";
    my $alldata = "";
    $lastdt = DateTime->now(time_zone => "local");
    
    my $skipdurationcheck = 0;
    my $loops = 0;
    while ( 1 ) #$socket->recv($data,1)
    {
        $| = 1;
        $loops++;
        $socket->autoflush;
        if($select->can_read(.25))
        {
            $socket->recv($response,1024);
            if($response ne '')
            {
                $lastdt = DateTime->now(time_zone => "local");
                $skipdurationcheck = 1;
                $self->{lastr} = $response;
                $self->{log}->addLine("SIPCLIENT data = $response");
                $self->{log}->addLine("SIPCLIENT alldata = $alldata");
                $alldata.=$response;
                if(length($alldata) > 0)
                {
                    if (  (ord(substr($alldata,-1)) eq "10")  || (ord(substr($alldata,-1)) eq "13") )
                    {
                        $self->{log}->addLine("SIPCLIENT return carrage detected");
                        last;
                    }
                }
            }
            else
            {
                print "Data was blank client $loops " if(($loops % 30) == 0);
                print "data: $alldata\n" if(($loops % 30) == 0);
            }
        }
        # Let's assume that we are not going to get data beyond what we already have
        # after waiting for .5 second
        if( ( duration($self) >  .5 ) && $alldata ne '' )
        {
            print "it's been longer than .5 seconds and we have $alldata\n";
            last;
        }
        if(!is_healthy($self)) {last;}
        if( (duration($self) > $self->{timeout}) && !$skipdurationcheck )
        {
            # We're dead, let's seppuku
            return "NOT CONNECTED\r";
        }
    }
    
    print "received response: $alldata\n";
    return $alldata;
}

sub duration
{
    my $self = shift;
    my $afterProcess = DateTime->now(time_zone => "local");
    my $difference = $afterProcess - $lastdt;
    my $format = DateTime::Format::Duration->new(pattern => '%M:%S');
    my $duration =  $format->format_duration($difference);
    my @s = split(/:/,$duration);
    my $minutes = @s[0]+0;
    my $seconds = @s[1]+0;
    my $seconds = ($minutes*60) + $seconds;
    return $seconds;
}

sub is_healthy
{
    my $self = shift;
    # print Dumper($self->{connection}->error);
    return !$self->{connection}->error;
}
 
sub DESTROY
{
	my $self = shift;
	$self->{connection}->close();
    shutdown($self->{connection}, 2);
	undef $self->{connection};
	undef $self;
}

1;
