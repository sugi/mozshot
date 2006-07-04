class UiController < ApplicationController

  def index
    set_param
    begin
      case GetText.locale.language
      when "ja"
        File.open("hatena-bookmarks.html"){|f| @demo = f.read }
      else
        File.open("delicious-bookmarks.html"){|f| @demo = f.read }
      end
    rescue # All mainly Errno::EPERM, Errno::ENOENT
      # ignore
    end
  end

  def simple
    set_param
    if !@uri
      redirect_to :action => 'index'
    end
  end

  def advanced
    set_param
    param = @params[:param] || {}
    if @uri
      @image_uri = @shotbase + '?' + param.map{|p| p.map{|v| CGI.escape v }.join('=') }.join(';')
    else
      @params[:param][:keepratio] = 'true'
      @params[:param][:effect]    = 'true'
    end
  end

  private
  def set_param
    #@shotbase = "http://#{request.host_with_port}/shot"
    @shotbase = "http://mozshot.nemui.org/shot"
    if @params[:param].nil? || @params[:param][:uri].nil?
      @params[:param] ||= Hash.new
      @params[:param][:uri] = "http://www.mozilla.org/"
    else
      @uri = CGI.escapeHTML @params[:param][:uri]
    end
  end
end
