#!/usr/bin/ruby
#
# Simple Web api frontend for mozshot
#
# Author: Tatsuki Sugiura <sugi@nemui.org>
# Lisence: Ruby's
#

require 'cgi'
require 'drb'
require 'rinda/rinda'
require 'digest/md5'
require 'time'

cache_dir = 'cache'
cache_expire = 1800
cid = $$
qid = ENV["UNIQUE_ID"] || $$+rand
cgi = CGI.new
uri = nil
winsize = [1000, 1000]
imgsize = [128, 128]
keepratio = true

if !cgi['uri'].empty?
  uri = cgi.params['uri'][0]
  wx, wy, ix, iy = cgi['win_x'], cgi['win_y'], cgi['img_x'], cgi['img_y']
  !wx.empty? && !wy.empty? and winsize = [wx.to_i, wy.to_i]
  !ix.empty? and imgsize[0] = ix.to_i
  !iy.empty? and imgsize[1] = iy.to_i
  cgi.params['noresize'][0] = "true" and imgsize = winsize
  keepratio = cgi.params['keepratio'][0] == "true" ? true : false
else
  uri = cgi.query_string
  case cgi.path_info
  when %r[^/large/?$]
    imgsize = [256, 256]
  when %r[^/small/?$]
    imgsize = [64, 64]
  when %r[^/(?:(\d+)x(\d+))?(?:-(\d+)x(\d+))?]
    $1 && $2 && $1.to_i != 0 && $2.to_i != 0 and imgsize = [$1.to_i, $2.to_i]
    if $3 && $4 && $3.to_i != 0 && $4.to_i != 0
      winsize = [$3.to_i, $4.to_i]
    else
      winsize[1] = (winsize[0]*imgsize[1]/imgsize[0]).to_i
      keepratio = false
    end
  end
end

if uri.nil? || uri.empty? || !%r{^(https?|ftp|about):}.match(uri)
  baseuri = "http://#{cgi.server_name}#{cgi.script_name}"
  target  = "http://www.google.com/"
  puts "Content-Type: text/plain",
       "",
       "Invalid Request.",
       "", "Usage Example: ",
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
       "   #{baseuri}/800x800-800x800?#{target}"
  exit
end

args = {:uri => uri, :opt => {}}
winsize.empty? or args[:opt][:winsize] = winsize.map {|i| i-8}
imgsize.empty? or args[:opt][:imgsize] = imgsize.map {|i| i-8}
args[:opt][:keepratio] = keepratio

cache_hash = Digest::MD5.hexdigest("#{[winsize, imgsize].join(",")}|#{uri}")
cache_path = "#{cache_dir}/#{cache_hash}"

begin
  cachestat = File.stat(cache_path)
  if cgi.params['nocache'][0] != 'true' && cachestat.size != 0 &&
      cachestat.mtime.to_i + cache_expire > Time.now.to_i
    if ENV['HTTP_IF_MODIFIED_SINCE'] &&
       ENV['HTTP_IF_MODIFIED_SINCE'] =~ /; length=0/
      # browser have broken cache... try force load
      open(cache_path) { |c|
        puts "Content-Type: image/png",
	     ""
        print c.read
      }
    elsif ENV['HTTP_IF_MODIFIED_SINCE'] &&
       Time.parse(ENV['HTTP_IF_MODIFIED_SINCE'].split(/;/)[0]) <= cachestat.mtime
      # no output mode.
      puts "Last-Modified: #{cachestat.mtime.httpdate}", ""
    else
      open(cache_path) { |c|
        puts "Content-Type: image/png",
	     "Last-Modified: #{cachestat.mtime.httpdate}",
	     ""
        print c.read
      }
    end
    exit
  elsif cgi.params['nocache'][0] != 'true'
    File.unlink(cache_path)
  end
rescue Errno::ENOENT, Errno::EPERM
  # ignore
end

DRb.primary_server || DRb.start_service('drbunix:')
ts = DRbObject.new_with_uri("drbunix:drbsock")
#ts = DRbObject.new_with_uri("drbunix:#{ENV['HOME']}/.mozilla/mozshot/default/drbsock")

ret = []
2.times {
  ts.write [:req, cid, qid, :shot_buf, args], Rinda::SimpleRenewer.new(30)
  ret = ts.take [:ret, cid, qid, nil, nil]
  break if ret[3] == :success 
  $stderr.puts "get error from server #{ret}"
  # if fail, try server restart...
  ts.write [:req, cid, "#{qid}-shutdown", :shtudown]
  ret = ts.take [:ret, cid, "#{qid}-shutdown", nil, nil]
}

if ret[3] == :success
  mtime = Time.now
  puts "Content-Type: image/png",
       "Last-Modified: #{mtime.httpdate}",
       ""
  image = ret[4]

  require 'RMagick'
  timg = Magick::Image.from_blob(image)[0]
  timg.background_color = '#333'
  shadow = timg.shadow(0, 0, 2, 0.9)
  shadow.background_color = '#FEFEFE'
  shadow.composite!(timg, Magick::CenterGravity, Magick::OverCompositeOp)
  image = shadow.to_blob

  print image
  #$stdout.close
  open(cache_path, "w") {|f|
    f << image
  }
  File.utime(Time.now, mtime, cache_path)
else
  puts "Content-Type: text/plain", "", "InternalError:"
  require 'pp'
  pp ret
  $stderr.puts "Error: #{ret.inspect}, #{$!}"
end
