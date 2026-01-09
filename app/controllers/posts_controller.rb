# frozen_string_literal: true

class PostsController < ApplicationController
  layout "pages"

  # GET /posts
  def index
    @posts = Post.published_posts.recent
  end

  # GET /posts/:slug
  def show
    @post = Post.published_posts.find_by!(slug: params[:slug])
    @recent_posts = Post.published_posts.recent.where.not(id: @post.id).limit(3)
  end
end
