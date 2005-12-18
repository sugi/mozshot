#!/usr/bin/ruby
#

require 'cgi'
require 'drb'
require 'rinda/rinda'

cid = $$
qid = ENV["UNIQUE_ID"] || $$+rand
cgi = CGI.new
uri = cgi.query_string
winsize = nil
imgsize = nil


if uri.nil? || uri.empty? || !%r{^https?://}.match(uri)
  puts("Content-Type: text/plain", "", "Invalid Request")
  exit
end

if %r[^/(?:(\d+)x(\d+))?(?:-(\d+)?x(\d+)?)?].match cgi.path_info
  $1 && $2 and winsize = [$1.to_i, $2.to_i]
  $3 || $4 and imgsize = [($3 ? $3.to_i : $1.to_i), ($4 ? $4.to_i : $2.to_i)]
end

reqargs = {:uri => uri, :opt => {}}
winsize and reqargs[:opt][:winsize] = winsize
imgsize and reqargs[:opt][:imgsize] = imgsize


DRb.start_service
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
  
