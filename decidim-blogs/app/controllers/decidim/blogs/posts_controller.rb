# frozen_string_literal: true

module Decidim
  module Blogs
    # Exposes the blog resource so users can view them
    class PostsController < Decidim::Blogs::ApplicationController
      include Flaggable
      include Paginable
      include Decidim::IconHelper

      redesign active: true

      helper_method :posts, :post, :post_presenter, :paginate_posts, :posts_most_commented, :tabs, :panels

      def index; end

      def show
        raise ActionController::RoutingError, "Not Found" unless post
      end

      private

      def paginate_posts
        @paginate_posts ||= paginate(posts.created_at_desc)
      end

      def post
        @post ||= posts.find(params[:id])
      end

      def post_presenter
        @post_presenter ||= Decidim::Blogs::PostPresenter.new(post)
      end

      def posts
        @posts ||= if current_user&.admin?
                     Post.where(component: current_component)
                   else
                     Post.published.where(component: current_component)
                   end
      end

      # PROVISIONAL if we implement counter cache
      def posts_most_commented
        @posts_most_commented ||= posts.joins(:comments).group(:id)
                                       .select("count(decidim_comments_comments.id) as counter")
                                       .select("decidim_blogs_posts.*").order("counter DESC").created_at_desc.limit(7)
      end

      def tabs
        @tabs ||= items.map { |item| item.slice(:id, :text, :icon) }
      end

      def panels
        @panels ||= items.map { |item| item.slice(:id, :method, :args) }
      end

      def items
        @items ||= [
          {
            enabled: post.photos.any?,
            id: "images",
            text: t("decidim.application.photos.photos"),
            icon: resource_type_icon_key("images"),
            method: :cell,
            args: ["decidim/images_panel", post]
          },
          {
            enabled: post.documents.any?,
            id: "documents",
            text: t("decidim.application.documents.documents"),
            icon: resource_type_icon_key("documents"),
            method: :cell,
            args: ["decidim/documents_panel", post]
          }
        ].select { |item| item[:enabled] }
      end
    end
  end
end
