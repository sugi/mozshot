#!/usr/bin/ruby

require 'drb'
require 'rinda/rinda'
require 'pstore'
require 'pp'
require 'digest/md5'
load "#{File.dirname(__FILE__)}/../web-ui/shot.cgi"


config = {:drburi => "druby://:7524"}
begin
  userconf = YAML.load(open("#{File.dirname(__FILE__)}/../config/config.yml"){|f| f.read})
  userconf && userconf.has_key?(:webclient) and config.merge! userconf[:webclient]
rescue Errno::ENOENT
  # ignore
end

DRb.start_service('druby://localhost:0')
ts = DRbObject.new_with_uri(config[:drburi])

write_count = 0
r = ts.read_all([:ret, nil, nil, nil])
r.each {|i|
  cur = nil
  begin
    cur = ts.take([i[0..2], nil].flatten, 0) or next
  rescue Rinda::RequestExpiredError
    next
  end
  shot = MozShotCGI.new(config)
  ret = cur[3] or next
  shot.cache_name = ret[:req][:cache_name]
  badfile = shot.cache_path+".badmark"
  delete_badfile_p = false
  metadata = {
      'Timestamp'   => ret[:timestamp].to_i,
      'OriginalURI' => ret[:req][:uri]
  }

  if Magick::Image.from_blob(ret[:image])[0].number_colors == 1
    puts "drop(single color): #{ret.reject{|k,v| k == :image}.inspect}"
    if File.exists?(shot.cache_path) &&
      Time.now.to_i < File.mtime(shot.cache_path).to_i + shot.opt[:cache_expire]
      puts "snapshot file already exists, ignore."
      next
    else
      i = 0
      open(badfile, "a+") { |b|
	i = b.read.to_i + 1
	b.rewind
	b << i
      }
      puts "set bad count = #{i}"
      i < 3 and next
      delete_badfile_p = true
      puts "bad cound limit exceeded. writing force: #{ret[:req][:uri]}"
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
    begin
      File.unlink shot.cache_path + ".queued"
    rescue Errno::ENOENT
      # ignore
    end
    write_count += 1
    delete_badfile_p and File.delete(badfile)
  end
}
puts "complete: wrote out #{write_count} images."

# vim: set sw=2 sts=2 expandtab:
