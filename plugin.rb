# name: sifhmail
# about: Mail template customizations for SIFH discourse
# version: 0.1
# authors: Paul Apostolos

after_initialize do
   UserNotifications.class_eval do
   	def self.mailing_list_notify(user, post)
      opts = {
		  post: post,
		  allow_reply_by_email: true,
		  use_site_subject: true,
		  add_re_to_subject: true,
		  show_category_in_subject: true,
		  notification_type: "posted",
		  notification_data_hash: {
			original_username: post.user.username,
			topic_title: post.topic.title,
		  },
		}
    notification_email(user, opts)
    end

    def self.email_post_markdown(post)
    	result = "[email-indent]\n"
    	result << "#{post.raw}\n\n"
    	result << "#{I18n.t('user_notifications.posted_by', username: post.username, post_date: post.created_at.strftime("%m/%d/%Y"))}\n\n"
    	result << "[/email-indent]\n"
    	result
  	end

	def self.get_context_posts(post, topic_user)
		context_posts = Post.where(topic_id: post.topic_id)
                        .where("post_number < ?", post.post_number)
                        .where(user_deleted: false)
                        .where(hidden: false)
                        .where(post_type: Topic.visible_post_types)
                        .order('created_at desc')
                        .limit(SiteSetting.email_posts_context)

    if topic_user && topic_user.last_emailed_post_number
      context_posts = context_posts.where("post_number > ?", topic_user.last_emailed_post_number)
    end

    context_posts
  end

    class UserNotificationRenderer < ActionView::Base
    	include UserNotificationsHelper
  	end

	def self.notification_email(user, opts)
		notification_type = opts[:notification_type]
		notification_data = opts[:notification_data_hash]
		post = opts[:post]

		unless String === notification_type
		  if Numeric === notification_type
			notification_type = Notification.types[notification_type]
		  end
		  notification_type = notification_type.to_s
		end

		user_name = notification_data[:original_username]

		if post && SiteSetting.enable_names && SiteSetting.display_name_on_email_from
		  name = User.where(id: post.user_id).pluck(:name).first
		  user_name = name unless name.blank?
		end

		title = notification_data[:topic_title]
		allow_reply_by_email = opts[:allow_reply_by_email] unless user.suspended?
		use_site_subject = opts[:use_site_subject]
		add_re_to_subject = opts[:add_re_to_subject]
		show_category_in_subject = opts[:show_category_in_subject]
		use_template_html = opts[:use_template_html]
		original_username = notification_data[:original_username] || notification_data[:display_username]

		send_notification_email(
		  title: title,
		  post: post,
		  username: original_username,
		  from_alias: user_name,
		  allow_reply_by_email: allow_reply_by_email,
		  use_site_subject: use_site_subject,
		  add_re_to_subject: add_re_to_subject,
		  show_category_in_subject: show_category_in_subject,
		  notification_type: notification_type,
		  use_template_html: use_template_html,
		  user: user
		)
	end

	
    def self.send_notification_email(opts)
		post = opts[:post]
		title = opts[:title]
		allow_reply_by_email = opts[:allow_reply_by_email]
		use_site_subject = opts[:use_site_subject]
		add_re_to_subject = opts[:add_re_to_subject] && post.post_number > 1
		username = opts[:username]
		from_alias = opts[:from_alias]
		notification_type = opts[:notification_type]
		user = opts[:user]
		# category name
		category = Topic.find_by(id: post.topic_id).category
		if opts[:show_category_in_subject] && post.topic_id && category && !category.uncategorized?
		  show_category_in_subject = category.name

		  # subcategory case
		  if !category.parent_category_id.nil?
			show_category_in_subject = "#{Category.find_by(id: category.parent_category_id).name}/#{show_category_in_subject}"
		  end
		else
		  show_category_in_subject = nil
		end
		
	  context = ""
	  tu = TopicUser.get(post.topic_id, user)
	  
	  context_posts = get_context_posts(post, tu)

	  # make .present? cheaper
	  context_posts = context_posts.to_a

	  if context_posts.present?
		context << "---\n*#{I18n.t('user_notifications.previous_discussion')}*\n"
		context_posts.each do |cp|
		  context << email_post_markdown(cp)
		end
	  end


      html = UserNotificationRenderer.new().render(
        file: '/plugins/sifhmail/app/views/email/notification',
        format: :html,
		locals: { context_posts: context_posts, post: post, top: nil }
      )

      template = "user_notifications.user_#{notification_type}"
      if post.topic.private_message?
        template << "_pm"
      end

      email_opts = {
        topic_title: title,
		  message: email_post_markdown(post),
		  url: post.url,
		  post_id: post.id,
		  topic_id: post.topic_id,
		  context: context,
		  username: username,
		  add_unsubscribe_link: !user.staged,
		  add_unsubscribe_via_email_link: user.mailing_list_mode,
		  unsubscribe_url: post.topic.unsubscribe_url,
		  allow_reply_by_email: allow_reply_by_email,
		  use_site_subject: use_site_subject,
		  add_re_to_subject: add_re_to_subject,
		  show_category_in_subject: show_category_in_subject,
		  private_reply: post.topic.private_message?,
		  include_respond_instructions: !user.suspended?,
		  template: template,
		  html_override: html,
		  site_description: SiteSetting.site_description,
		  site_title: SiteSetting.title,
		  style: :notification
      }
	  

      # If we have a display name, change the from address
      email_opts[:from_alias] = from_alias if from_alias.present?

      TopicUser.change(user.id, post.topic_id, last_emailed_post_number: post.post_number)

      build_email(user.email, email_opts)
    end
  end
end
