#!/usr/bin/ruby
#

require 'cgi'
require 'drb'
require 'rinda/rinda'

cache_dir = 'cache'
cache_expire = 300
cid = $$
qid = ENV["UNIQUE_ID"] || $$+rand
cgi = CGI.new
uri = nil
winsize = []
imgsize = []

if !cgi['uri'].empty?
  uri = cgi.params['uri'][0]
  wx, wy, ix, iy = cgi['win_x'], cgi['win_y'], cgi['img_x'], cgi['img_y']
  !wx.empty? && !wy.empty? and winsize = [wx.to_i, wy.to_i]
  !ix.empty? and imgsize[0] = ix.to_i
  !iy.empty? and imgsize[1] = iy.to_i
else
  uri = cgi.query_string
  if %r[^/(?:(\d+)x(\d+))?(?:-(\d+)?x(\d+)?)?].match cgi.path_info
    $1 && $2 and winsize = [$1.to_i, $2.to_i]
    $3 || $4 and imgsize = [($3 ? $3.to_i : $1.to_i), ($4 ? $4.to_i : $2.to_i)]
  end
end

if uri.nil? || uri.empty? || !%r{^https?://}.match(uri)
  puts("Content-Type: text/plain", "", "Invalid Request")
  exit
end

reqargs = {:uri => uri, :opt => {}}
winsize.empty? or reqargs[:opt][:winsize] = winsize
imgsize.empty? or reqargs[:opt][:imgsize] = imgsize

cache_hash = Digest::MD5.hexdigest("#{[winsize, imgsize].join(",")}|#{uri}")
cache_path = "#{cache_dir}/#{cache_hash}"

begin
  if File.mtime(cache_path).to_i + 300 > Time.now.to_i
    open(cache_path) { |c|
      puts "Content-Type: image/png", "", c.read
      exit
  end
rescue Errno::ENOENT
  # ignore
end

DRb.start_service('drbunix:')
ts = DRbObject.new_with_uri("drbunix:drbsock")
#ts = DRbObject.new_with_uri("drbunix:#{ENV['HOME']}/.mozilla/mozshot/default/drbsock")

ts.write [:req, cid, qid, :shot_buf, reqargs], Rinda::SimpleRenewer.new(60)

ret = ts.take [:ret, cid, qid, nil, nil]

if ret[3] == :success
  puts "Content-Type: image/png", ""
  print ret[4]

  open(cache_path, "w") {|f|
    f << ret[4]
  }
else
  puts "Content-Type: text/plain", "", "InternalError:"
  require 'pp'
  pp ret
end
