#!/usr/bin/env ruby
# 
# MozShot - Web site thumbnail service by gtkmozembed.
#
# Copyright (C) 2005 Tatsuki Sugiura <sugi@nemui.org>
# Released under the License same as Ruby.
#
# 
# This was based on MozSnapshooter written by Mirko Maischberger.
#   http://mirko.lilik.it/Ruby-GNOME2/moz-snapshooter.rb
#
# Origianl idea by Andrew McCall - <andrew@textux.com>
#   http://www.hackdiary.com/archives/000055.html
#
# And I refered many similar implementations. Thanks for all!
# 

require 'gtkmozembed'
require 'thread'
require 'timeout'

class MozShot
  class InternalError < StandardError; end
  def initialize(useropt = {})
    if ENV['MOZILLA_FIVE_HOME']
       Gtk::MozEmbed.set_comp_path(ENV['MOZILLA_FIVE_HOME'])
    end
    @opt = { :mozprofdir => "#{ENV['HOME']}/.mozilla/mozshot",
             :winsize => [800, 800], :imgsize => [],
	     :timeout => 30, :imgformat => "png", :keepratio => true }
    @opt.merge! useropt
    @window = nil
    @moz    = nil
    @mutex  = Hash.new {|h, k| h[k] = Mutex.new }
    if File.symlink? "#{opt[:mozprofdir]}/default/lock"
      @mozprof = "proc-#{$$}"
      puts "Using profile #{@mozprof}"
      require 'fileutils'
      begin
        FileUtils.cp_r "#{opt[:mozprofdir]}/default",
		     "#{opt[:mozprofdir]}/#{@mozprof}"
        File.unlink "#{opt[:mozprofdir]}/#{@mozprof}/lock"
      rescue Errno::ENOENT, Errno::EEXIST
        # ignore
      end
      # Signal trap will not works...?
      trap(:INT, "FileUtils.rm_rf('#{opt[:mozprofdir]}/#{@mozprof}')".untaint )
      trap(:QUIT, "FileUtils.rm_rf('#{opt[:mozprofdir]}/#{@mozprof}')".untaint )
      trap(:TERM, "FileUtils.rm_rf('#{opt[:mozprofdir]}/#{@mozprof}')".untaint )
      trap(:ABRT, "FileUtils.rm_rf('#{opt[:mozprofdir]}/#{@mozprof}')".untaint )
    else
      @mozprof = 'default'
    end
    Gtk.init
    Gtk::MozEmbed.set_profile_path opt[:mozprofdir], @mozprof
    @gtkthread = Thread.new { Gtk.main }
  end
  attr_accessor :opt, :gtkthread

  def join
    @gtkthread.join
  end

  def renew_mozwin(useropt = {})
    @mutex[:mozwin].synchronize {
      topt = opt.dup.merge! useropt
      w = Gtk::Window.new
      #w.title = "MozShot"
      w.decorated = false
      w.has_frame = false
      w.border_width = 0
      w.resize(topt[:winsize][0], topt[:winsize][1])
      m = Gtk::MozEmbed.new
      m.chrome_mask = Gtk::MozEmbed::ALLCHROME
      w << m
      @moz.nil? or @moz.destroy
      @window.nil? or @window.destroy
      @window = w
      @moz    = m
    }
    @window.show_all
    @window.move(0,0)
  end

  def screenshot_file(uri, filename, useropt = {})
    File.open(filename, "w") {|f|
      f << screenshot(uri, useropt)
    }
    filename
  end

  def screenshot(url, useropt = {})
    shotopt = opt.dup.merge! useropt
    q = Queue.new
    @mutex[:shot].synchronize {
      renew_mozwin(shotopt)
      @moz.signal_connect("net_stop") {
        begin
          Gtk::timeout_add(100) {
            q.push :loaded
            false
          }
        rescue => e
          puts e.class, e.message, e.backtrace
        end
      }

      puts "Loading: #{url}"
      @moz.location = url
      pixbuf = nil

      begin
        timeout(opt[:timeout]){
          q.pop
          pixbuf = getpixbuf(@window.child.parent_window, shotopt)
        }
      rescue Timeout::Error
        puts "Timeouted."
        # TODO
        Gtk::Window.toplevels.each { |w|
          # I can't close modal dialog....
          w.modal? and raise InternalError,
            "MozShot gone to wrong state. pelease restart process..."
        }
        raise
      end

      if shotopt[:imgsize] && !shotopt[:imgsize].empty? &&
	   shotopt[:imgsize] != shotopt[:winsize]
        width, height = *shotopt[:imgsize]
        if shotopt[:keepratio]
          ratio = shotopt[:winsize][0].to_f / shotopt[:winsize][1]
          if width.to_i.zero? || !height.to_i.zero? && height * ratio < width
            width  = height * ratio
          elsif height.to_i.zero? || !width.to_i.zero? && width / ratio < height
            height = width / ratio
          end
        end
        pixbuf = pixbuf.scale(width, height, Gdk::Pixbuf::INTERP_HYPER)
      end
      pixbuf.save_to_buffer(opt[:imgformat])
    }
  end

  def getpixbuf(gdkw, shotopt = {})
    x, y, width, height, depth = gdkw.geometry
    Gdk::Pixbuf.from_drawable(nil, gdkw, 0, 0, width, height)
  end

  def cleanup
    @moz and @moz.location = "about:blank"
    #GC.start
  end

  def shutdown
    Gtk.main_quit
    if @mozprof != 'default'
      FileUtils.rm_rf("#{opt[:mozprofdir]}/#{@mozprof}")
    end
    join
  end
end


if __FILE__ == $0
  ms = MozShot.new

  if ARGV.length == 0
    puts "Usage: $0 <URL> [outputfile (default='mozshot.png')]"
  elsif ARGV[0] == "-d"
    require 'drb'
    require 'rinda/rinda'
    DRb.start_service('drbunix:')
    drburi = ARGV[1] || "drbunix:#{ENV['HOME']}/.mozilla/mozshot/drbsock"
    ts = Rinda::TupleSpaceProxy.new(DRbObject.new_with_uri(drburi))
    ms.renew_mozwin
    i = 0
    loop {
      puts "waiting for request..."
      req = ts.take [:req, nil, nil, Symbol, Hash]
      print "took request: "
      p req
      begin
        if req[3] == :shot_buf
          buf = ms.screenshot(req[4][:uri], req[4][:opt]||{})
	  buf or raise "[BUG] Unknown Error: screenshot() returned #{buf.inspect}"
          ts.write [:ret, req[1], req[2], :success, buf], 300
        elsif req[3] == :shot_file
          filename = ms.screenshot_file(req[4][:uri], req[4][:filename],
                                        req[4][:opt]||{})
	  filename or raise "[BUG] Unknown Error: screenshot_file() returned #{filename.inspect}"
          ts.write [:ret, req[1], req[2], :success, buf], 300
        elsif req[3] == :shutdown
          ts.write [:ret, req[1], req[2], :accept, "going shutdown"]
          puts "shutdown request was accepted, going shutdown."
          break
        else
          raise "Unknown request"
        end
      rescue InternalError => e
        ts.write [:ret, req[1], req[2], :error, e.message]
        raise e
      rescue => e
        ts.write [:ret, req[1], req[2], :error, e.message]
      end
      ms.cleanup

      # I cannot use inifinite loop until solving mem leak problem...
      i += 1
      if i > 60
        puts "max times exeeded, going shutdown"
        break
      end
    }
  else
    ms.screenshot_file ARGV[0], (ARGV[1]|| "mozshot.png")
  end
  ms.shutdown
end
