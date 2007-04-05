#!/usr/bin/ruby
require 'rss/1.0'
require 'rss/2.0'
require 'rss/dublincore'
require 'rss/syndication'
require 'rss/content'
require 'open-uri'
require 'digest/md5'
require 'pstore'
require 'fileutils'
require 'erb'

class RSSFetcher
  def initialize(uri, option={})
    @uri = uri
    @opt = {
      :cache_dir => "/tmp/rss-fetch"
    }
    @opt.update option
    @fetched_p = false
    FileUtils.mkpath(@opt[:cache_dir]) unless File.directory? @opt[:cache_dir]
    @cache = PStore.new("#{@opt[:cache_dir]}/#{Digest::MD5.hexdigest(uri)}")
    @rss = nil
  end

  def fetch
    begin
      rss_source = open(@uri,
                        "If-Modified-Since" => last_fetch_time.httpdate)
    rescue OpenURI::HTTPError => e
      if /^304 /.match(e.message)
        @cache.transaction {
          @rss = @cache[:rss]
        }
      else
        raise
      end
    end
    if rss_source
      rss_str = filter_badutf8(rss_source.read)
      begin
        @rss = RSS::Parser.parse(rss_str)
      rescue RSS::InvalidRSSError
        @rss = RSS::Parser.parse(rss_str, false)
      end
      @cache.transaction {
        @cache[:rss] = @rss
        @cache[:last_modified] = rss_source.last_modified
      }
    end
    @rss
  end

  def last_fetch_time
    t = nil
    @cache.transaction {
      t = @cache[:last_modified]
    }
    t ? t : Time.at(0)
  end


  def filter_badutf8(str)
    require 'iconv'
    ret = ""
    while str.length > 0
      begin
        ret += Iconv.iconv("UTF-8", "UTF-8", str).to_s
        str = ""
      rescue Iconv::InvalidCharacter, Iconv::IllegalSequence => e
        ret += e.success.to_s + "?"
        str = e.failed.to_s[1..-1]
      end
    end
    ret.delete!("\x0b") # rexml can't parse some asci...?
    ret
  end
end


uri = $ARGV[0] || 'http://b.hatena.ne.jp/hotentry?mode=rss'

#tmpl = Amrita::TemplateText.new(open("rss-template.html").read)
#tmpl.prettyprint = true
#tmpl.expand(STDOUT, RSSMapper.new(RSSFetcher.new(uri).fetch))

rss = RSSFetcher.new(uri).fetch
ret = ERB.new(File.open($ARGV[2]||"rss-template.html").read).result(binding)

output = $ARGV[1] ? open($ARGV[1], "w")  : $defout
output.print ret
