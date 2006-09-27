#!/usr/bin/ruby

require 'fcgiwrap'
load 'shot.cgi'

FCGIWrap.each {
  MozShotCGI.new(:shot_background => true).run
  #MozShotCGI.new.run
}
