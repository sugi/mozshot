#!/usr/bin/ruby

require 'drb'
#require 'rinda/tuplespace'
require 'pp'

DRb.start_service('drbunix:')
ts = DRbObject.new_with_uri(ARGV[0])

loop {
  r = ts.read_all([nil, nil, nil, nil])
  r.each {|i| pp i[0..2] }
  puts "#{r.length} tabpples."
  sleep 3
  puts "-----------"
}

