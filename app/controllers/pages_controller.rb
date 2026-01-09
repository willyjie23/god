class PagesController < ApplicationController
  layout "pages"

  def home
    @recent_posts = Post.for_homepage
  end
end
