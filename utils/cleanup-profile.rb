#!/usr/bin/ruby
#

require 'socket'
require 'fileutils'
require 'drb'
require 'timeout'

ARGV.each { |p|
  File.directory? "#{p}/chrome" or next
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
      end
    end
  rescue Errno::ECONNREFUSED
    FileUtils.rm_rf(p)
    puts "cleanup: #{p}"
  rescue Errno::ENOENT
    puts "skip: #{p}"
    # ignore
  end
}

# vim: set sw=2:
# vim: set sts=2:
