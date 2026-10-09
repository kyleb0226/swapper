class PagesController < ApplicationController
  def home
    redirect_to home_path_for(Current.user) if signed_in?
  end

  def about
  end
end
