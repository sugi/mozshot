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
require 'timeout'
require 'pstore'
require 'RMagick'

class MozShotCGI
  class Request
    def initialize(cgi = nil)
      @uri = nil
      @opt = {:imgsize => [128, 128], :winsize => [1100, 1100], :retry => 1,
              :effect => true, :timeout => 10, :shot_timeouted => true}
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

      winsize = []
      !wx.empty? && wx.to_i != 0 and winsize[0] = wx.to_i
      !wy.empty? && wy.to_i != 0 and winsize[1] = wy.to_i
      winsize[1] and winsize[0] ||= winsize[1]
      winsize[0] and winsize[1] ||= winsize[0]
      !winsize.empty? and @opt[:winsize] = winsize

      if cgi.params['noresize'][0] == "true"
        @opt[:imgsize] = @opt[:winsize]
      else
        imgsize = []
        !ix.empty? && ix.to_i != 0 and imgsize[0] = ix.to_i
        !iy.empty? && iy.to_i != 0 and imgsize[1] = iy.to_i
        imgsize[1] and imgsize[0] ||= imgsize[1]
        imgsize[0] and imgsize[1] ||= imgsize[0]
        !imgsize.empty? and @opt[:imgsize] = imgsize
      end
      
      @opt[:keepratio] = cgi.params['keepratio'][0] == "true"  ? true : false
      @opt[:effect]    = cgi.params['effect'][0]    != "false" ? true : false
    end

    def read_cgireq_pathinfo(cgi)
      @uri = cgi.query_string

      case cgi.path_info
      when %r[^/large/?]
        @opt[:imgsize] = [256, 256]
      when %r[^/small/?]
        @opt[:imgsize] = [64, 64]
      when %r[^/(?:(\d+)x(\d+))?(?:-(\d+)x(\d+))?]
        $1.to_i != 0 && $2.to_i != 0 and @opt[:imgsize] = [$1.to_i, $2.to_i]
        if $3.to_i != 0 && $4.to_i != 0
          @opt[:winsize] = [$3.to_i, $4.to_i]
        elsif @opt[:imgsize]
          @opt[:winsize][1] = (@opt[:winsize][0].to_f * @opt[:imgsize][1] / @opt[:imgsize][0]).to_i
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

  ALLOW_URI_PATTERN = %r{^(https?://(?!(localhost|127\.0\.0\.1))|about:)};

  def initialize(opt = {})
    @opt = {
      :drburi        => "drbunix:drbsock",
      :cache_dir     => "cache",
      :cache_baseurl => "/cache", # must start with /
      :cache_expire  => 10800,
      :force_nocache => false,
      :internal_redirect  => true,
      :shot_background    => false,
      :background_wait    => 0,
      :expire_real_delete => false
    }
    @opt.merge! opt
    @cgi = nil
    @req = nil
    @ts  = nil
    @cache_name = nil
    @cache_path = nil
    @cache_file = nil
    @cache_base = nil
    @break_len  = 4
  end
  attr_writer :cgi, :ts, :req,
    :cache_name, :cache_base, :cache_file, :cache_path
  attr_accessor :opt, :break_len

  def ts
    @ts and return @ts
    DRb.primary_server || DRb.start_service('druby://localhost:0')
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

  def cache_name
    @cache_name and return @cache_name
    @cache_name  = Digest::MD5.hexdigest([req.opt[:winsize],
                                          req.opt[:imgsize],
                                          req.opt[:effect],
                                          req.uri].flatten.join(",")) +
        ".#{req.uri[req.uri.length/2, 4].unpack('H*').join}" +
        "-#{req.uri.length}.png"
  end

  def cache_base
    @cache_base and return @cache_base
    @cache_base  = "#{opt[:cache_dir]}/#{cache_name[0, break_len]}"
  end

  def cache_file
    @cache_file and return @cache_file
    @cache_file  = "#{cache_name[0, break_len]}/#{cache_name}"
  end

  def cache_path
    @cache_path and return @cache_path
    @cache_path  = "#{opt[:cache_dir]}/#{cache_file}"
  end

  def run
    cgi.params['bg'][0] == 'false' and opt[:shot_background] = false
    #cgi.path_info =~ %r[/nobg/?] and opt[:shot_background] = false # TODO: change to proper way...
    header = "Content-Type: text/plain"
    body   = ""
    begin
      prepare_cache_file
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
          header = "Last-Modified: #{mtime.httpdate}"
          body = ""
        else
          header = "Content-Type: image/png\r\nLast-Modified: #{mtime.httpdate}"
          open(cache_path) {|c|
            body = c.read
          }
        end
        if opt[:force_nocache]
          header += "\r\nCache-Contro: no-cache\r\nPragma: no-cache\r\nExpires: Mon, 26 Jul 1997 05:00:00 GMT"
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
      STDERR.puts "#{Time.now}: Error: #{e.inspect} #{e.message}: #{e.backtrace.join("\n")}, req=#{@req.inspect}"
    rescue => e
      header = "Content-Type: text/plain"
      body = "Internal Error:\n#{e.inspect}"
      STDERR.puts "#{Time.now}: Unhandled Exception: #{e.inspect} #{e.message}: #{e.backtrace.join("\n")}, req=#{@req.inspect}"
    ensure
      cgi.print header, "\r\n\r\n"
      cgi.print body
      $defout.flush
    end
  end

  def prepare_cache_file
    cache_queue = cache_path + ".queued"
    cache_tmp   = cache_path + ".tmp"

    run_other_queue = false
    begin
      if File.mtime(cache_queue).to_i + req.opt[:timeout]*(req.opt[:retry].to_i+1) > Time.now.to_i
        run_other_queue = true
        if !opt[:shot_background]
          # wait for other queue
          timeout(req.opt[:timeout]*(req.opt[:retry].to_i+1)+1) {
            loop { open(cache_queue).close; sleep 0.2 }
          }
        end
      else
        File.unlink(cache_queue)
      end
    rescue Errno::ENOENT, Timeout::Error
      # ignore, ENOENT means ready for cache_file
    rescue IOError
      # ignore...?
    end

    begin
      st = File.stat(cache_path)
      if st.size != 0 && cgi.params['nocache'][0] != 'true' &&
          (st.mtime.to_i + opt[:cache_expire] > Time.now.to_i || run_other_queue && opt[:shot_background])
        return cache_file
      elsif cgi.params['nocache'][0] != 'true'
        File.unlink(cache_path) if opt[:expire_real_delete]
      end
    rescue Errno::ENOENT
      # ignore
    end

    File.directory? cache_base or Dir.mkdir(cache_base)

    begin
      begin
        img = get_image
        open(cache_tmp, "w") { |t|
          t << img
        }
      rescue Rinda::RequestExpiredError
        if !File.exists?(cache_path)
          open(cache_tmp, "w") { |c|
            c << get_waitimage
          }
          File.utime(0, 0, cache_tmp)
        end
        #opt[:internal_redirect] = false
        #opt[:force_nocache] = true
      end
      begin
        if !File.zero?(cache_tmp)
          File.rename(cache_tmp, cache_path) 
        end
      rescue Errno::ENOENT
        # ignore
      end
    ensure
      begin
        File.unlink(cache_tmp)
      rescue Errno::ENOENT
        # ignore
      end
    end

    cache_file
  end

  def gen_actual_reqopt
    lopt = req.opt.dup
    if lopt[:effect]
      lopt[:winsize].nil? or lopt[:winsize] = lopt[:winsize].map {|i| i-8}
      lopt[:imgsize].nil? or lopt[:imgsize] = lopt[:imgsize].map {|i| i-8}
    end
    lopt
  end

  def get_waitimage
    lopt = gen_actual_reqopt
    image = waitimage(*lopt[:imgsize])
    lopt[:effect] and image = do_effect(image)
    image
  end

  def get_image
    lopt = gen_actual_reqopt
    cache_queue = cache_path + ".queued"
    args = {:uri => req.uri, :opt => lopt}
    qid = nil

    queue = PStore.new(cache_queue)
    begin
      queue.transaction do |q| q[:test]; end
    rescue TypeError
      File.unlink(cache_queue)
      queue = PStore.new(cache_queue)
    end
    
    queue.transaction do |q|
      qid = (q[:qid] ||= "#{$$}.#{args.__id__}")
      q[:req] ||= req
      q[:opt] ||= lopt
    end

    image = request_screenshot(qid, args, (opt[:shot_background] ? opt[:background_wait] : nil))
    lopt[:effect] and image = do_effect(image)
    image
  end

  def request_queued?(qid)
    begin
      # check doubled queue
      ts.read [nil, qid, nil, nil], 0
    rescue Rinda::RequestExpiredError
      return false
    end
    true
  end

  def request_screenshot(qid, args, timeout = nil)
    if args[:uri].nil? || args[:uri].empty? || args[:uri] !~ ALLOW_URI_PATTERN
      raise Invalid, "Invalid URI."
    elsif args[:opt][:winsize] &&
      (args[:opt][:winsize][0] < 100 || args[:opt][:winsize][1] < 100 ||
       args[:opt][:winsize][0] > 3000 || args[:opt][:winsize][1] > 3000)
      raise Invalid, "Invalid window size."
    elsif args[:opt][:imgsize] &&
      (args[:opt][:imgsize][0] < 16 || args[:opt][:imgsize][1] < 16 ||
       args[:opt][:imgsize][0] > 5000 || args[:opt][:imgsize][1] > 5000)
      raise Invalid, "Invalid image size."
    end

    ret = nil
    args[:timestamp]  = Time.now
    args[:cache_name] = cache_name
    timeout.nil? || !request_queued?(qid) and
      ts.write [:req, qid, :shot_buf, args],
               Rinda::SimpleRenewer.new(args[:opt][:timeout]*(args[:opt][:retry]+1)*2)
    if timeout.nil?
      ret = ts.take([:ret, qid, nil, nil], nil)
    else
      t = timeout.to_f
      begin
        ret = ts.take([:ret, qid, nil, nil], 0)
      rescue Rinda::RequestExpiredError
        if t > 0
          sleep 0.2
          t -= 0.2
          retry
        end
        raise
      end
    end
    return ret[3][:image] if ret[2] == :success && !ret[3].nil? && !ret[3][:image].nil?
    STDERR.puts "Error from server, return failimage: #{ret.inspect}, args=#{args.inspect}"
    failimage(*args[:opt][:imgsize])
  end

  def emptyimage(width, height)
    Magick::Image.new(width, height) {
      self.background_color = 'white'
    }
  end

  def failimage(width, height)
    img = emptyimage(width, height)
    gc = Magick::Draw.new
    gc.stroke('transparent')
    gc.font_family('times')
    gc.pointsize(16)
    gc.text_align(Magick::RightAlign)
    gc.font_weight(Magick::BoldWeight)
    gc.fill('#FFCCCC')
    gc.text(width-5, height-5, 'Error...')
    gc.draw(img)
    img.format='png'
    img.to_blob
  end

  def waitimage(width, height)
    img = emptyimage(width, height)
    gc = Magick::Draw.new
    gc.stroke('transparent')
    gc.font_family('times')
    gc.pointsize(15)
    gc.text_align(Magick::RightAlign)
    gc.font_weight(Magick::BoldWeight)
    gc.fill('#CCCCCC')
    gc.text(width-5, height-21, 'Now')
    gc.text(width-5, height-5, 'Printing')
    gc.draw(img)
    img.format='png'
    img.to_blob
  end

  def do_effect(image)
    timg = Magick::Image.from_blob(image)[0]
    timg.background_color = '#333'
    shadow = timg.shadow(0, 0, 2, 0.9)
    shadow.background_color = '#FEFEFE'
    shadow.composite!(timg, Magick::CenterGravity, Magick::OverCompositeOp)
    shadow.to_blob
  end
end

if __FILE__ == $0
  MozShotCGI.new.run
end

# vim: set sts=2:
# vim: set expandtab:
# vim: set shiftwidth=2:
