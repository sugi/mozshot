#!/usr/bin/ruby
#

require 'socket'
require 'fileutils'
require 'drb'
require 'timeout'

threads = []

ARGV.each { |p|
  threads << Thread.new {
    #File.directory? "#{p}/Cache" or next
    begin
      UNIXSocket.open("#{p}/drbsock").close
      puts "connect ok: #{p}"
      begin
	drb = DRbObject.new_with_uri("drbunix:#{p}/drbsock")
	begin
	  timeout(30) {
	    drb.ping
	  }
          puts "ping ok: #{p}"
	rescue Timeout::Error
	  puts "killing: #{p}"
	  begin
	    Process.kill(:SEGV, File.basename(p).sub(/^proc-/, '').to_i)
	    sleep 1
	    Process.kill(:KILL, File.basename(p).sub(/^proc-/, '').to_i)
	  rescue Errno::ESRCH
	    # ignore
	  end
	  FileUtils.rm_rf(p)
	rescue NoMethodError => e
	  STDERR.puts "wierd profile: #{p}; #{e.inspect}"
	  puts "wierd profile: #{p}; #{e.inspect}"
	end
      end
    rescue Errno::ECONNREFUSED, Errno::ENOENT, DRb::DRbConnError
      FileUtils.rm_rf(p)
      puts "cleanup: #{p}"
      begin
	Process.kill(:KILL, File.basename(p).sub(/^proc-/, '').to_i)
      rescue Errno::ESRCH
	# ignore
      end
    end
  }
}

threads.each {|t| t.join }

# vim: set sw=2:
# vim: set sts=2:
