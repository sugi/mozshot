#!/usr/bin/ruby
#

require 'drb'
require 'rinda/rinda'

DRb.start_service
ts = DRbObject.new_with_uri("drbunix:#{ENV['HOME']}/.mozilla/mozshot/default/drbsock")

ARGV.each_with_index {|uri, i|
  ts.write [:req, "myid000", uri.__id__, :shot_file, {:uri => uri, :filename => "shot#{i}.png"}], Rinda::SimpleRenewer.new(30)
}

#loop {
#  p ts.take([:ret, "myid000", nil, nil, nil])
#}
