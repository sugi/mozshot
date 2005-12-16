#!/usr/bin/ruby

require 'pp'
require 'drb'
require 'rinda/tuplespace'
ts = Rinda::TupleSpace.new
DRb.start_service('drbunix:/home/sugi/.mozilla/mozshot/default/drbsock',
		  ts, {:UNIXFileMode => 0600})
puts DRb.uri
DRb.thread.join
