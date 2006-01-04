require 'gettext/rails'

class UiController < ApplicationController
  init_gettext "mozshot"

  def view
    if params[:commit]
      #params[:uri] and @reqstr = params[:uri]
      @reqstr =
        {
          :uri => params[:uri],
          :win_x => params[:win_x],
          :win_y => params[:win_y],
          :img_x => params[:img_x],
          :img_y => params[:img_y]
        }.map {|k, v|
          v.empty? ? nil : "#{k}=#{CGI.escape(v)}"
        }.compact.join(';')
    end
  end
end

