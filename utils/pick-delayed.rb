#!/usr/bin/ruby

require 'drb'
require 'rinda/rinda'
require 'pstore'
require 'find'

DRb.start_service('drbunix:')
ts = DRbObject.new_with_uri(ARGV[0])

Find.find(ARGV[1]) { |f|
  case f
  when /.queued$/
    begin
      File.mtime($`).to_i == 0 or next
      File.mtime(f).to_i + 120 > Time.now.to_i and next
      qid = nil
      PStore.new(f).transaction do |q|
        qid = q[:qid]
      end
      begin
        image = ts.take([:ret, qid, :success, nil], 0)[3][:image]
        open("#{$`}.tmp", "w") {|t| t << image }
        File.rename("#{$`}.tmp", $`)
        puts "write #{$`}"
      rescue Rinda::RequestExpiredError
        puts "expire #{f}"
        File.unlink(f)
      end

    rescue TypeError, Errno::ENOENT => e
      #puts "skip #{f}: #{e}"
      # ignore
    end
  when /.png$/
    #
  end
  #r = ts.take([:ret, cid, qid, :success, nil], 0)
}

# vim: set sts=2:
# vim: set ts=2:
# vim: set shiftwidth=2:
# vim: set expandtab:
