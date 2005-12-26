#!/usr/bin/ruby

require 'drb'
require 'pp'

#DRb.start_service('drbunix:')
ts = DRbObject.new_with_uri(ARGV[0])

loop {
  pp ts.read_all([nil, nil, nil, nil, nil])
  sleep 3
  puts "-----------"
}

