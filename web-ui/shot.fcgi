#!/usr/bin/ruby

require 'fcgiwrap'
load 'shot.cgi'

FCGIWrap.each {
  MozShotCGI.new.run
}
