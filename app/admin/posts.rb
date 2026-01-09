# frozen_string_literal: true

ActiveAdmin.register Post do
  menu priority: 2, label: "最新消息"

  # 因為 Post model 的 to_param 回傳 slug，ActiveAdmin URL 會使用 slug
  # 需要同時支援 ID（數字）和 slug（字串）查詢
  controller do
    def find_resource
      scoped_collection.find_by(id: params[:id]) || scoped_collection.find_by!(slug: params[:id])
    end
  end

  # 允許的參數
  permit_params :title, :slug, :summary, :content, :status, :published_at

  # 篩選器
  filter :title_cont, label: "標題"
  filter :status, as: :select, collection: -> {
    Post.statuses.map { |k, v| [ I18n.t("post_statuses.#{k}"), k ] }
  }, label: "狀態"
  filter :published_at, label: "發布時間"
  filter :created_at, label: "建立時間"

  # 列表頁
  index do
    selectable_column
    id_column
    column "標題", :title, sortable: :title do |post|
      link_to post.title.truncate(30), admin_post_path(post)
    end
    column "狀態", :status, sortable: :status do |post|
      case post.status
      when "published"
        status_tag "已發布", class: "green"
      else
        status_tag "草稿", class: "orange"
      end
    end
    column "發布時間", :published_at, sortable: :published_at do |post|
      post.published_at&.strftime("%Y/%m/%d %H:%M") || "-"
    end
    column "建立時間", :created_at, sortable: :created_at do |post|
      post.created_at.strftime("%m/%d %H:%M")
    end
    actions do |post|
      if post.draft?
        item "發布", publish_admin_post_path(post), method: :put, class: "member_link"
      else
        item "取消發布", unpublish_admin_post_path(post), method: :put, class: "member_link"
      end
    end
  end

  # 詳細頁
  show do
    attributes_table title: "文章資訊" do
      row "標題", &:title
      row "網址代稱" do |post|
        code post.slug
      end
      row "狀態" do |post|
        case post.status
        when "published"
          status_tag "已發布", class: "green"
        else
          status_tag "草稿", class: "orange"
        end
      end
      row "發布時間", &:published_at
      row "作者" do |post|
        post.author&.email || "未指定"
      end
      row "建立時間", &:created_at
      row "更新時間", &:updated_at
    end

    panel "摘要" do
      div style: "padding: 15px; background: #f9f9f9; border-radius: 4px;" do
        simple_format(resource.summary.presence || "（無摘要）")
      end
    end

    panel "文章內容" do
      div style: "padding: 15px; line-height: 1.8;" do
        simple_format(resource.content)
      end
    end

    panel "快速操作" do
      if resource.draft?
        para link_to "發布文章", publish_admin_post_path(resource),
                     method: :put, class: "button",
                     data: { confirm: "確定要發布這篇文章嗎？" }
      else
        para link_to "取消發布", unpublish_admin_post_path(resource),
                     method: :put, class: "button",
                     data: { confirm: "確定要取消發布嗎？文章將變為草稿狀態。" }
        para link_to "前往前台查看", post_path(resource.slug),
                     class: "button", target: "_blank"
      end
    end
  end

  # 表單
  form do |f|
    f.inputs "文章資訊" do
      f.input :title, label: "標題", hint: "文章標題，將顯示在列表和詳細頁"
      f.input :slug, label: "網址代稱", hint: "URL 友善名稱，留空將自動生成。例如：spring-ceremony-2026"
      f.input :summary, as: :text, label: "摘要",
              input_html: { rows: 3 },
              hint: "文章摘要，顯示在列表頁，建議 50-100 字"
    end

    f.inputs "文章內容" do
      f.input :content, as: :text, label: "內容",
              input_html: { rows: 15 },
              hint: "支援純文字或 HTML 格式"
    end

    f.inputs "發布設定" do
      f.input :status, as: :select,
              collection: Post.statuses.keys.map { |k| [ I18n.t("post_statuses.#{k}"), k ] },
              include_blank: false, label: "狀態"
      f.input :published_at, as: :datetime_picker, label: "發布時間",
              hint: "設定為「已發布」且發布時間在現在之前，文章才會在前台顯示"
    end

    f.actions
  end

  # 自動設定作者
  before_create do |post|
    post.author = current_admin_user
  end

  # 自訂動作：發布
  member_action :publish, method: :put do
    resource.publish!
    redirect_to admin_post_path(resource), notice: "文章已發布"
  end

  # 自訂動作：取消發布
  member_action :unpublish, method: :put do
    resource.unpublish!
    redirect_to admin_post_path(resource), notice: "文章已取消發布，改為草稿狀態"
  end

  # 匯出 CSV
  csv do
    column :id
    column("標題") { |p| p.title }
    column("網址代稱") { |p| p.slug }
    column("狀態") { |p| I18n.t("post_statuses.#{p.status}") }
    column("發布時間") { |p| p.published_at }
    column("作者") { |p| p.author&.email }
    column("建立時間") { |p| p.created_at }
  end
end
