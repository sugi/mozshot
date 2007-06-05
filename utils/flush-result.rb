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
  cur = nil
  begin
    cur = ts.take([i[0..2], nil].flatten, 0) or next
  rescue Rinda::RequestExpiredError
    next
  end
  shot = MozShotCGI.new
  ret = cur[3] or next
  shot.cache_name = ret[:req][:cache_name]
  metadata = {
      'Timestamp'   => ret[:timestamp].to_i,
      'OriginalURI' => ret[:req][:uri]
  }
  image = Magick::Image.from_blob(ret[:image])[0]
  if image.number_colors == 1
    ret.delete(:image)
    msg = "drop(single color): #{ret.inspect}"
    STDERR.puts "drop(single color): #{ret.inspect}"
    next
  end
  image = shot.add_metadata(ret[:image], metadata)
  if ret[:req] && ret[:req][:opt][:effect]
    image = shot.do_effect(image)
  end
  open(shot.cache_path+".tmp", "w") { |t|
    t << image
  }
  begin
    File.rename(shot.cache_path+".tmp", shot.cache_path)
    puts "write: #{shot.cache_path} (#{ret[:req][:uri]})"
  end
}

# vim: set sw=2:
# vim: set sts=2:
