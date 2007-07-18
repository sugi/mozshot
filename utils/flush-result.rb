#!/usr/bin/ruby

require 'drb'
require 'rinda/rinda'
require 'pstore'
require 'pp'
require 'digest/md5'
load 'shot.cgi'

DRb.start_service('drbunix:')
ts = DRbObject.new_with_uri(ARGV[0])

write_count = 0
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

  if Magick::Image.from_blob(ret[:image])[0].number_colors == 1
    ret.delete :image
    puts "drop(single color): #{ret.inspect}"
    if File.exists? shot.cache_path
      puts "snapshot file already exists, ignore."
      next
    else
      badfile = shot.cache_path+".badmark"
      i = 0
      open(badfile, "a+") { |b|
	i = b.read.to_i
	b.rewind
	b << i+1
      }
      puts "set bad count = #{i}"
      i < 3 and next
      File.delete badfile
      msg = "bad cound limit exceeded. writing force: #{ret[:req][:uri]}"
      puts msg
      $stderr.puts msg
    end
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
    write_count += 1
  end
}
puts "complete: wrote out #{write_count} images."

# vim: set sw=2:
# vim: set sts=2:
