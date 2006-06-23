#!/usr/bin/ruby
#

require 'drb'
require 'rinda/rinda'

DRb.start_service('drbunix:')
ts = DRbObject.new_with_uri("drbunix:#{ENV['HOME']}/.mozilla/mozshot/default/drbsock")

ARGV.each_with_index {|uri, i|
  print "Sending request for #{uri}..."
  ts.write [:req, $$, uri.__id__, :shot_file, {:uri => uri, :filename => "shot#{$$}-#{i}.png"}], Rinda::SimpleRenewer.new(30)
  puts "done."
  print "Waiting for result..."
  ret = ts.take [:ret, $$, uri.__id__, nil, nil]
  if ret[3] == :success
    puts "done. screenshot was saved in #{ret[4]}"
  else
    puts "fail! #{ret[4]}"
  done
}
