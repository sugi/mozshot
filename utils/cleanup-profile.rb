#!/usr/bin/ruby
#

require 'socket'
require 'fileutils'
require 'drb'
require 'timeout'

ARGV.each { |p|
  File.directory? "#{p}/Cache" or next
  begin
    UNIXSocket.open("#{p}/drbsock").close
    puts "ok: #{p}"
    begin
      drb = DRbObject.new_with_uri("drbunix:#{p}/drbsock")
      begin
        timeout(30) {
	  puts drb.inspect
	  puts drb.to_s
	  drb.screenshot("about:blank")
        }
      rescue Timeout::Error
	puts "killing: #{p}"
	Process.kill(:KILL, File.basename(p).sub(/^proc-/, '').to_i)
	FileUtils.rm_rf(p)
      rescue NoMethodError => e
	STDERR.puts "wierd profile: #{p}; #{e.inspect}"
	puts "wierd profile: #{p}; #{e.inspect}"
      end
    end
  rescue Errno::ECONNREFUSED, Errno::ENOENT
    FileUtils.rm_rf(p)
    puts "cleanup: #{p}"
    begin
      Process.kill(:SEGV, File.basename(p).sub(/^proc-/, '').to_i)
      sleep 1
      Process.kill(:KILL, File.basename(p).sub(/^proc-/, '').to_i)
    rescue Errno::ESRCH
      # ignore
    end
  end
}

# vim: set sw=2:
# vim: set sts=2:
