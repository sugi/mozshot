#!/usr/bin/ruby
#!/home/sugi/bin/ruby-trunk-13997/bin/ruby

require 'pp'
require 'drb'
require 'rinda/tuplespace'
require 'yaml'

config = {
  :drburi => "druby://:7524",
  :drbopt => {:UNIXFileMode => 0600},
  :pidfile => "ts.pid",
}

END {
  config[:pidfile] && File.exists(config[:pidfile]) && File.unlink(config[:pidfile])
}

begin
  userconf = YAML.load(open("config/config.yml"){|f| f.read})
  userconf && userconf.has_key?(:tuplespace) and config.merge! userconf[:tuplespace]
rescue Errno::ENOENT
  # ignore
end

open(config[:pidfile], "w") {|pid|
  pid << $$
}

ts = Rinda::TupleSpace.new
DRb.start_service(config[:drburi], ts, config[:drbopt])
puts DRb.uri
Thread.new { loop { sleep 600; GC.start } }
DRb.thread.join

# vim: sts=2 sw=2 expandtab:
