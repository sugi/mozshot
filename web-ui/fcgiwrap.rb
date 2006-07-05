#
# FastCGI Wrapper
#   trick to wrap a cgi in fastcgi easily
#
# Author: Tatsuki Sugiura <sugi@nemui.org>
# Licence: Ruby's
#
#
# Usage:
#  write wrapper script like following;
#    require 'fcgiwrap'
#    FCGIWrap.each {
#      load '/path/to/original.cgi'
#    }

require 'cgi'
require 'fcgi'

# for ruby 1.8 blow
if RUBY_VERSION.tr(".", "0").to_i < 10801
  alias $stdout $defout
  def ENV.clear
    ENV.each_key {|k| ENV.delete(k) }
  end
  def ENV.update(from)
    from.each {|k,v| ENV[k] = v}
  end
end

class FCGIWrap
  VERSION = "0.1.4"
  @@cgi = nil
  @@shutdown = false
  class << self
    def cgi
      @@cgi
    end

    def each_request
      trap(:PIPE){ exit } 
      trap(:TERM){ @@cgi ? (@@shutdown = true) : exit } 
      trap(:INT){ @@cgi ? (@@shutdown = true) : exit } 
      FCGI.each_cgi { |@@cgi|
	ENV.clear
	ENV.update(@@cgi.env_table)
        begin
          yield
	rescue SystemExit
	  @@shutdown && raise
        ensure
          @@cgi = nil
          #Thread.list.each { |t|
          #  Thread.current == t and next
          #  t.kill
          #}
        end
	@@shutdown && exit
      }
    end
    alias each each_request
    alias each_cgi each_request
    alias loop each_request
  end
end

module Kernel
  def print(*args)
    if FCGIWrap.cgi
      FCGIWrap.cgi.print(*args)
    else
      # IGNORE: 
      # STDERR.puts "WARN: Useless print"
    end
  end
  def puts(*args)
    Kernel.print(*args.map{|s| t = s.dup.to_s; t !~ /\n$/ and $t += "\n"; t })
  end
end

class CGI
  class << self
    def new(*args)
      FCGIWrap.cgi ? FCGIWrap.cgi : super(*args)
    end
  end
end

