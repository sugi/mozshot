#!/usr/bin/ruby
#

require 'cgi'
require 'drb'
require 'rinda/rinda'

cid = $$
qid = ENV["UNIQUE_ID"] || $$+rand
cgi = CGI.new
uri = nil
winsize = nil
imgsize = nil

if !cgi['uri'].empty?
  uri = cgi.params['uri'][0]
  !cgi['win_x'].empty? && !cgi['win_y'].empty? and
    winsize = [cgi['win_x'].to_i, cgi['win_y'].to_i]
  if !cgi['img_x'].empty? || !cgi['img_y'].empty?
    imgsize = []
    !cgi['img_x'].empty? and imgsize[0] = cgi['img_x'].to_i
    !cgi['img_y'].empty? and imgsize[1] = cgi['img_y'].to_i
  end
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
winsize and reqargs[:opt][:winsize] = winsize
imgsize and reqargs[:opt][:imgsize] = imgsize

DRb.start_service('drbunix:')
ts = DRbObject.new_with_uri("drbunix:drbsock")
#ts = DRbObject.new_with_uri("drbunix:#{ENV['HOME']}/.mozilla/mozshot/default/drbsock")

ts.write [:req, cid, qid, :shot_buf, reqargs], Rinda::SimpleRenewer.new(60)

ret = ts.take [:ret, cid, qid, nil, nil]

if ret[3] == :success
  puts "Content-Type: image/png"
  puts
  print ret[4]
else
  puts "Content-Type: text/plain"
  puts
  p ret
end
  
