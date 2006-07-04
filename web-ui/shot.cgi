#!/usr/bin/ruby
#
# Simple Web API for mozshot
#
# Author: Tatsuki Sugiura <sugi@nemui.org>
# Lisence: Ruby's
#

require 'drb'
require 'rinda/rinda'
require 'digest/md5'

class MozShotCGI
  class Request
    def initialize(cgi = nil)
      @uri = nil
      @opt = {:imgsize => [128, 128], :effect => true}
      cgi and read_cgireq(cgi)
    end
    attr_accessor :uri, :opt
    
    def read_cgireq(cgi)
      if !cgi['uri'].empty?
        read_cgireq_standard(cgi)
      else
        read_cgireq_pathinfo(cgi)
      end
    end
   
    def read_cgireq_standard(cgi)
      @uri = cgi.params['uri'][0]

      wx, wy, ix, iy = cgi['win_x'], cgi['win_y'], cgi['img_x'], cgi['img_y']
      !wx.empty? && !wy.empty? and @opt[:winsize] = [wx.to_i, wy.to_i]

      if cgi.params['noresize'][0] == "true"
        @opt[:imgsize] = @opt[:winsize]
      else
        imgsize = []
        !ix.empty? and imgsize[0] = ix.to_i
        !iy.empty? and imgsize[1] = iy.to_i
        !imgsize.empty? and @opt[:imgsize] = imgsize
      end
      
      @opt[:keepratio] = cgi.params['keepratio'][0] == "true"  ? true : false
      @opt[:effect]    = cgi.params['effect'][0]    != "false" ? true : false
    end

    def read_cgireq_pathinfo(cgi)
      @uri = cgi.query_string

      case cgi.path_info
      when %r[^/large/?$]
        @opt[:imgsize] = [256, 256]
      when %r[^/small/?$]
        @opt[:imgsize] = [64, 64]
      when %r[^/(?:(\d+)x(\d+))?(?:-(\d+)x(\d+))?]
        $1.to_i != 0 && $2.to_i != 0 and @opt[:imgsize] = [$1.to_i, $2.to_i]
        if $3.to_i != 0 && $4.to_i != 0
          @opt[:winsize] = [$3.to_i, $4.to_i]
	elsif @opt[:imgsize]
          winsize = [1000, 1000]
          winsize[1] = (winsize[0].to_f * @opt[:imgsize][1] / @opt[:imgsize][0]).to_i
          @opt[:winsize] = winsize
          @opt[:keepratio] = false
        end
      end
    end

  end # class Request

  class ReqComplete < StandardError; end
  class Invalid     < ReqComplete; end
  class Fail        < ReqComplete; end

  require 'cgi'
  require 'drb'
  require 'rinda/rinda'
  require 'digest/md5'
  require 'time'

  def initialize(opt = {})
    @opt = {
      :drburi        => "drbunix:drbsock",
      :cache_dir     => "cache",
      :cache_baseurl => "/cache", # must start with /
      :cache_expire  => 1800,
      :internal_redirect => true
    }
    @opt.merge! opt
    @cgi = nil
    @req = nil
    @ts  = nil
  end
  attr_writer :cgi, :ts, :req
  attr_accessor :opt, :cache_name

  def ts
    @ts and return @ts
    DRb.primary_server || DRb.start_service('drbunix:')
    @ts = DRbObject.new_with_uri(opt[:drburi])
  end

  def cgi
    @cgi and return @cgi
    @cgi = CGI.new
  end

  def req
    @req and return @req
    @req = Request.new(cgi)
  end

  def run
    header = "Content-Type: text/plain"
    body   = ""
    begin
      cache_file = get_image_filename
      cache_path = "#{opt[:cache_dir]}/cache_file"
      if opt[:internal_redirect]
        # use apache internal redirect
        header = "Location: #{opt[:cache_baseurl]}/#{cache_file}"
        body = ""
      else
	require 'time' 
	mtime = File.mtime(cache_path)
        if ENV['HTTP_IF_MODIFIED_SINCE'] &&
           ENV['HTTP_IF_MODIFIED_SINCE'] =~ /; length=0/
          # browser have broken cache... try force load
          header = "Content-Type: image/png"
	  open(cache_path) {|c|
            body = c.read
	  }
	elsif ENV['HTTP_IF_MODIFIED_SINCE'] &&
	   Time.parse(ENV['HTTP_IF_MODIFIED_SINCE'].split(/;/)[0]) <= mtime
	  # no output mode.
	  head = "Last-Modified: #{mtime.httpdate}"
	  body = ""
	else
          header = "Content-Type: image/png\nLast-Modified: #{mtime.httpdate}"
	  open(cache_path) {|c|
            body = c.read
	  }
	end
      end
    rescue Invalid
      header = "Content-Type: text/plain"
      baseuri = "http://#{cgi.server_name}#{cgi.script_name}"
      target  = "http://www.google.com/"
      body = ["Invalid Request.",
              "",
              "Usage Example: ",
              " - Simple:",
              "   #{baseuri}?#{target}",
              " - Get small (64x64) image:",
              "   #{baseuri}/small?#{target}",
              " - Get large (256x256) image:",
              "   #{baseuri}/large?#{target}",
              " - Get 800x600 image:",
              "   #{baseuri}/800x600?#{target}",
              " - Set browser window size to 300x300:",
              "   #{baseuri}/-300x300?#{target}",
              " - Specify window & image size:",
              "   #{baseuri}/800x800-800x800?#{target}"].join("\n")
    rescue Fail => e
      header = "Content-Type: text/plain"
      body = "Internal Error:\n#{e.inspect}"
      $stderr.puts "#{Time.now}: Error: #{e.inspect}, req={@req.inspect}"
    rescue => e
      header = "Content-Type: text/plain"
      body = "Internal Error:\n#{e.inspect}"
      $stderr.puts "#{Time.now}: Unhandled Exception: #{e.inspect}, req={@req.inspect}"
    ensure
      puts header, ""
      print body
    end
  end

  def get_image_filename
    break_len = 4
    cache_name = Digest::MD5.hexdigest([req.opt.to_a, req.uri].flatten.join(","))+".png"
    cache_base = "#{opt[:cache_dir]}/#{cache_name[0, break_len]}"
    cache_file = "#{cache_name[0, break_len]}/#{cache_name}"
    cache_path = "#{opt[:cache_dir]}/#{cache_file}"

    begin
      st = File.stat(cache_path)
      if st.size != 0 && cgi.params['nocache'][0] != 'true' &&
          st.mtime.to_i + opt[:cache_expire] > Time.now.to_i
        return cache_file
      elsif cgi.params['nocache'][0] != 'true'
        File.unlink(cache_path)
      end
    rescue Errno::ENOENT, Errno::EPERM
      # ignore
    end

    File.directory? cache_base or Dir.mkdir(cache_base)
    open(cache_path, "w") { |c|
      c << get_image
    }

    return cache_file
  end

  def get_image
    opt = req.opt.dup

    if req.opt[:effect]
      opt[:winsize].nil? or opt[:winsize] = opt[:winsize].map {|i| i-8}
      opt[:imgsize].nil? or opt[:imgsize] = opt[:imgsize].map {|i| i-8}
    end

    image = request_screenshot({:uri => req.uri, :opt => opt})
    req.opt[:effect] and image = do_effect(image)
    image
  end

  def request_screenshot(args)
    if args[:uri].nil? || args[:uri].empty?
      raise Invalid, "Target URI is empty."
    end

    cid = $$
    qid = ENV["UNIQUE_ID"] || $$+rand

    3.times {
      ts.write [:req, cid, qid, :shot_buf, args], Rinda::SimpleRenewer.new(30)
      ret = ts.take [:ret, cid, qid, nil, nil]
      return  ret[4]  if ret[3] == :success && !ret[4].nil?

    }
    raise Fail, "Error from server: #{ret[4]}"
  end

  def do_effect(image)
    require 'RMagick'
    timg = Magick::Image.from_blob(image)[0]
    timg.background_color = '#333'
    shadow = timg.shadow(0, 0, 2, 0.9)
    shadow.background_color = '#FEFEFE'
    shadow.composite!(timg, Magick::CenterGravity, Magick::OverCompositeOp)
    shadow.to_blob
  end
end

class MozShotFCGI < MozShotCGI
  require 'fcgi'

  def cgi
    @cgi
  end

  def run
    FCGI::each_cgi { |cgi|
      $defout = cgi.stdoutput
      @cgi = cgi
      super
      @cgi = nil
      @req = nil
    }
  end
end

if __FILE__ == $0
  MozShotCGI.new.run
end
