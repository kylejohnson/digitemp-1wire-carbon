#!/usr/bin/perl

# The latest release of this script can be 
# found at https://github.com/kylejohnson/digitemp-1wire-carbon

use strict;
use warnings;
use IO::Socket::INET;

# Configure these settings to match your system.
my $path_to_digitemp_bin = '/usr/local/bin/digitemp';
my $path_to_digitemp_conf = '/usr/local/etc/digitemp.conf';
my $carbon_port = 2003;
my $carbon_host = '127.0.0.1';
my $carbon_proto = 'tcp';
my $logfile = '/var/log/1wire.log';

# Digitemp doesn't allow you to give a sensor a name, instead you access them
# numerically. Here I am matching up sensor names with the order in which
# Digitemp returns  them so that I can give them a name.  The array index
# of a sensor name matches the number that Digitemp gives that sensor.
my @sensors = (
  'Kitchen',
  'Bed_Room',
  'Workshop',
  'Weight_Room',
  'Computer_Room'
);

# The base Digitemp command that I'm going to call.
my $dt = "$path_to_digitemp_bin -q -c $path_to_digitemp_conf";

# The socket on which my Carbon (graphite) server is listening.
my $socket = new IO::Socket::INET (
  PeerHost => $carbon_host,
  PeerPort => $carbon_port,
  Proto => $carbon_proto,
) or die "Error in Socket Creation : $!\n";

# Open the log file.
open my $file, ">>$logfile" or die $!;

# The grep line is new to me.  It is a way of determining the index number of
# an array's value.  For every sensor, I am grabbing its SensorID, getting the
# sensor's value (temperature) based on the SensorID, and then sending that
# value to carbon.
foreach my $sensor (@sensors) {
  my( $s ) = grep { $sensors[$_] eq $sensor } 0..$#sensors;
  my $temp = get_data($s);

  insert($s, $sensor, $temp);
}

# Look up a sensor's value by a sensor ID.
# The value that Digitemp returns includes the epoch timestamp, so that I do
# not need to look it up separately.
sub get_data {
  my $sensor = $_[0];
  my $data = "$dt -t $sensor -o\"%F %N\"";
  chomp($data = `$data`);
  return $data;
}

# Send the sensor value, sensor name and timestamp to the socket and log file.
sub insert {
  my ($sensor_id, $sensor_name, $temperature) = @_;
  my $data = "house.environment.temperature.$sensor_name $temperature\n";
  print $socket $data;
  print $file $data;
}

close $file;
$socket->close();
