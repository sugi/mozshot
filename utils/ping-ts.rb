#!/usr/bin/ruby

require 'drb'
require 'rinda/rinda'

DRb.start_service('drbunix:')
ts = DRbObject.new_with_uri(ARGV[0])

begin
  ts.read([], 0)
rescue Rinda::RequestExpiredError
  exit 0
end
