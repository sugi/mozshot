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
      puts drb.inspect
      puts drb.to_s
      begin
        timeout(30) {
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
  end
}

# vim: set sw=2:
# vim: set sts=2:
