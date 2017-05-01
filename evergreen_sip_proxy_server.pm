#!/usr/bin/perl
#

package evergreen_sip_proxy_server;

use DateTime;
use utf8;
use IO::Socket::INET;
use Data::Dumper;
use evergreen_sip_proxy_listener;

sub new
{
    my $class = shift;
    my @a = ();
    my $self = 
	{
        port => shift,
        log => shift,
        conf => shift,
        connection => shift,
        listeners => \@a
	};
    
	bless $self, $class;
    return $self;
}


sub start
{
    my $self = @_[0];
    sip_listen($self);
    die "server died";
}

sub sip_listen
{
    my $self = @_[0];
    $self->{connection}->close() if($self->{connection});
    undef $self->{connection};
    # auto flush socket
    $| = 1;
    # creating a listening socket
    $self->{connection} = new IO::Socket::INET (
        LocalHost => '0.0.0.0',
        LocalPort => $self->{port},
        Proto => 'tcp',
        Listen => 45,
        Reuse => 1,
    );
    die "cannot create socket $!\n" unless $self->{connection};
    print "server waiting for client connection\n";
  
    print "Server Socket:\n";
    print "sock->connected  : ", ($self->{connection}->connected  || ''), "\n";
    print "sock->sockport   : ", ($self->{connection}->sockport   || ''), "\n";
    print "sock->protocol   : ", ($self->{connection}->protocol   || ''), "\n";
    print "sock->sockdomain : ", ($self->{connection}->sockdomain || ''), "\n";
    print "sock->socktype   : ", ($self->{connection}->socktype   || ''), "\n";
    print "sock->timeout    : ", ($self->{connection}->timeout    || ''), "\n";
     
    print "\n";
    
    while(is_healthy($self))
    {   
        my $newclient = new evergreen_sip_proxy_listener($self->{connection},$self->{log},$self->{conf});
        my $data = $newclient->socketlisten();
        my $thread = threads->create( 'spin_thread', $newclient, $data );
        $thread->detach();
        # push $self->{listeners}, $thread;
        $self->{log}->addLogLine("SIPPROXYSERVER Thread[$$]  OK - we had a new client, so we are waiting for a new one now");
    }

    $self->{connection}->close();
}

sub is_healthy
{
    my $self = shift;
    print Dumper($self->{connection});
    return !$self->{connection}->error;
}

sub spin_thread
{
    my $client = shift;
    my $data = shift;
    #print "Thread starting with this:\n".Dumper($client);
    # print Dumper($data);
    $client->continueconversation($data);
}
 
sub DESTROY
{
	my $self = @_[0];
	$self->{connection}->close();
    shutdown($self->{connection}, 2);
	undef $self->{connection};
	undef $self;
}

1;
