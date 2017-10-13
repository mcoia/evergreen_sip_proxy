# evergreen_sip_proxy
## Synopsis

This project was created to solve an issue with SIP traffic over the internet. Some SIP devices complain when the communication is interrupted and do not resolve immediately. This can cause a poor user experience when interacting with the SIP device. This project will act as a proxy on the local network where the SIP device can connect over the LAN. This code will copy and paste the SIP commands from one socket to another and it will retry the command on the backend without letting the local connection know that it was temporarily disconnected from the *real* SIP server. In addition to acting as proxy, this software also allow for a SSH tunnel for SIP traffic over the internet. This proxy server was created specifically for the Evergreen ILS but it should work for just about any SIP traffic. It is programmed to save the 93 message in case it gets disconnected, it will use the login message again to re-establish the connection without letting it's client know.

## Getting Started

This code has only been tested on Ubuntu 16.04. I am sure it will work on other distros but it's not been tested. You will need perl and several perl modules:
utf8
DateTime
Getopt::Long 
Data::Dumper
IO::Socket::INET
IO::Select
threads

Copy this repo onto the Ubuntu machine. You will need to edit your config file and use sip_proxy_config_file_sample.conf as an example. If you choose to use an SSH tunnel, you will need to create your SSH key pair and setup the tunnel.

Once you have your config ready, you can launch the software with ./sip_proxy.pl --config [configfile]
and that's it.


## Automation

I have included an ansible script that should set all of this up for you. There is a configuration file for the ansible script: 16.04.yml. Customize the values in that file, and execute ansible-playbook install_sip_proxy_server.yml.

## Testing

I have included a local script that you can execute to interact with the proxy server. You will need to have your login message ready to paste into the command.
./sip_client.pl
This script assumes a great deal about your configuration, so you might want to make sure you edit the logfile path and ip/port of the local proxy server.

## Additional notes

Feel free to read through my notes: raspberry pi installation notes.txt. Here I have links to the raspberry pi image and some shell commands to remove tons of default packages that come with Ubuntu MATE.

## Contributors

My name is Blake Graham-Henderson and I work for MOBIUS library consortium. I am the sole contributor to this project right now. If you find issues or improvements, PLEASE feel free to tinker!

## License

Everything in this repository is open and free to use under the GNU.


This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
	