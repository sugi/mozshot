#!/usr/bin/ruby

require 'fcgiwrap'
load 'shot.cgi'

config = {:shot_background => true}
begin
  userconf = YAML.load(open("../conf/config.yml"){|f| f.read})
  userconf && userconf.has_key?(:webclient) and config.merge! userconf[:webclient]
rescue Errno::ENOENT
  # ignore
end

FCGIWrap.each {
  MozShotCGI.new(config).run
}

# vim: sts=2 sw=2 expandtab filetype=ruby:
