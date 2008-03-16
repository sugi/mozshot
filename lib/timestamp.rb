ENV['LANG']='C'
ENV['LC_ALL']='C'
module Timestamp__
  
  Started = Time.now
  Format  = "%b %d %X #{File.basename($0)}[#{$$}]: "
  puts Timestamp__::Started.strftime(Timestamp__::Format) + "start."

  module ExtPuts
    def self.included(target_class)
      target_class.class_eval {
	alias_method :puts_orig, :puts
	def puts(*args)
	  args[0] = Time.now.strftime(Timestamp__::Format) + args[0].to_s
	  self.__send__ :puts_orig, *args
	end
      }
    end
  end

  module ExtPrintf
    def self.included(target_class)
      target_class.class_eval {
	alias_method :printf_orig, :printf
	@@head_of_line = true
	def printf(*args)
	  unless args[0].kind_of?(IO)
	    if @@head_of_line
	      args[0] = Time.now.strftime(Timestamp__::Format) + args[0].to_s
	    end
	    args[0] =~ /\n\Z/ ? @@head_of_line = true : @@head_of_line = false
	  end
	  self.__send__ :printf_orig, *args
	end
      }
    end
  end
end

class << $stderr
  include Timestamp__::ExtPrintf
  include Timestamp__::ExtPuts
end

class << $stdout
  include Timestamp__::ExtPrintf
  include Timestamp__::ExtPuts
end

include Timestamp__::ExtPrintf
include Timestamp__::ExtPuts

END {
  finished = Time.now
  puts_orig finished.strftime(Timestamp__::Format) +
       "finished. escaped time: #{finished - Timestamp__::Started} sec."
}
