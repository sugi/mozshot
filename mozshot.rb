#!/usr/bin/env ruby
# 
# MozShot - Web site thumbnail service by gtkmozembed.
#
# Copyright (C) 2005 Tatsuki Sugiura
# Released in the Ruby License
# 
# This was based on MozSnapshooter written by Mirko Maischberger.
#   http://mirko.lilik.it/Ruby-GNOME2/moz-snapshooter.rb
#
# Origianl idea by Andrew McCall - <andrew@textux.com>
#   http://www.hackdiary.com/archives/000055.html
#
# And I refered many similar implementation. Thanks for all!
# 

require 'gtkmozembed'
require 'thread'
require 'timeout'
require 'tempfile'

class MozShot
  class InternalError < StandardError; end
  def initialize(useropt = {})
    if ENV['MOZILLA_FIVE_HOME']
       Gtk::MozEmbed.set_comp_path(ENV['MOZILLA_FIVE_HOME'])
    end
    @opt = { :mozprofdir => "#{ENV['HOME']}/.mozilla/mozshot",
             :winsize => [1000, 1000], :imgsize => [],
	     :timeout => 30, :imgformat => "png", :keepratio => true }
    @opt.merge! useropt
    @window = nil
    @moz    = nil
    @mutex  = Hash.new {|h, k| h[k] = Mutex.new }
    Gtk.init
    Gtk::MozEmbed.set_profile_path opt[:mozprofdir], 'default'
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
      w.title = "MozShot"
      #w.decorated = false
      #w.has_frame = false
      #w.border_width = 0
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

  def screenshot(uri, useropt = {})
    tempfile = Tempfile.new("mozshot")
    screenshot_file(uri, tempfile.path, useropt)
    tempfile.rewind
    buf = tempfile.read
    tempfile.close(true)
    buf
  end

  def screenshot_file(url, filename, useropt = {})
    shotopt = opt.dup.merge! useropt
    q = Queue.new
    @mutex[:shot].synchronize {
      renew_mozwin(shotopt)
      gdkw = @window.child.parent_window
      @moz.signal_connect("net_stop") {
        begin
          Gtk::timeout_add(100) {
            q.push getpixbuf(gdkw, shotopt)
            false
          }
        rescue => e
          puts e.class, e.message, e.backtrace
        end
      }
      @moz.location = url
      pixbuf = nil

      begin
        timeout(opt[:timeout]){ pixbuf = q.pop }
      rescue Timeout::Error
        # TODO
        Gtk::Window.toplevels.each { |w|
          # I can't close modal dialog....
          w.modal? and raise InternalError,
            "MozShot gone to wrong state. pelease restart process..."
        }
        return nil
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
        pixbuf.scale!(width, height, Gdk::Pixbuf::INTERP_HYPER)
      end
      pixbuf.save(filename, opt[:imgformat])
      filename
    }
  end

  def getpixbuf(gdkw, shotopt = {})
    x, y, width, height, depth = gdkw.geometry
    Gdk::Pixbuf.from_drawable(nil, gdkw, 0, 0, width, height)
  end

  def cleanup
    @moz and @moz.location = "about:blank"
  end

  def shutdown
    Gtk.main_quit
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
    drburi = ARGV[1] || "drbunix:#{ENV['HOME']}/.mozilla/mozshot/default/drbsock"
    ts = Rinda::TupleSpaceProxy.new(DRbObject.new_with_uri(drburi))
    loop {
      STDERR.puts "waiting for request..."
      req = ts.take [:req, nil, nil, Symbol, Hash]
      STDERR.print "took request: "
      p req
      begin
        if req[3] == :shot_buf
          ts.write [:ret, req[1], req[2], :success,
		    ms.screenshot(req[4][:uri], req[4][:opt]||{})], 300
        elsif req[3] == :shot_file
          ts.write [:ret, req[1], req[2], :success,
		    ms.screenshot_file(req[4][:uri], req[4][:filename], req[4][:opt]||{})], 300
        else
          raise "Unknown request"
        end
      rescue => e
        ts.write [:ret, req[1], req[2], :error, e.message]
      end
      ms.cleanup
    }
  else
    ms.screenshot_file ARGV[0], (ARGV[1]|| "mozshot.png")
  end
  ms.shutdown
end
