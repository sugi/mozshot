#!/usr/bin/ruby

require 'drb'
#require 'rinda/tuplespace'
require 'pp'

DRb.start_service('drbunix:')
ts = DRbObject.new_with_uri(ARGV[0])

loop {
  r = ts.read_all([nil, nil, nil, nil])
  stat = Hash.new(0)
  r.each {|i| stat[i[2]] += 1 }
  puts "#{Time.now.strftime('%Y-%m-%d %T')}: #{stat.sort_by{|k,| k.to_s}.map{|v| "%s: %2d" % v }.join(', ')}, total: #{r.length} tabpples."
  sleep 10
}

