#!/usr/bin/ruby

require 'drb'
#require 'rinda/tuplespace'
require 'pp'

DRb.start_service('drbunix:')
ts = DRbObject.new_with_uri(ARGV[0])
sleep_sec = ARGV[1] ? ARGV[1].to_i : 10

loop {
  r = ts.read_all([nil, nil, nil, nil])
  r.each {|i| pp i[2] == :shot_buf ? [i[0..2], i[3][:uri]].flatten: i[0..2]; }
  puts "#{r.length} tabpples."
  sleep sleep_sec
  puts "-----------"
}

