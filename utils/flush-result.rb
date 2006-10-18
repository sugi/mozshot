#!/usr/bin/ruby

require 'drb'
require 'rinda/rinda'
require 'pstore'
require 'pp'
load 'shot.cgi'

DRb.start_service('drbunix:')
ts = DRbObject.new_with_uri(ARGV[0])

r = ts.read_all([:ret, nil, nil, nil])
r.each {|i|
  begin
    ts.take([i[0..2], nil].flatten, 0)
  rescue Rinda::RequestExpiredError
    next
  end
  shot = MozShotCGI.new
  shot.cache_name = i[3][:req][:cache_name]
  image = i[3][:image]
  if i[3][:req] && i[3][:req][:opt][:effect]
    image = shot.do_effect(image)
  end
  open(shot.cache_path+".tmp", "w") { |t|
    t << image
  }
  begin
    File.rename(shot.cache_path+".tmp", shot.cache_path)
    puts "write: #{shot.cache_path} (#{i[3][:req][:uri]})"
  end
}

# vim: set sw=2:
# vim: set sts=2:
