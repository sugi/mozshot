class UiController < ApplicationController

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
        }.map {|i|
          i[1].empty? ? nil : "#{i[0]}=#{CGI.escape(i[1])}"
        }.compact.join(';')
    end
  end
end

