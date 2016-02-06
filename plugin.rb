# name: sifhmail
# about: Mail template customizations for SIFH discourse
# version: 0.1
# authors: Paul Apostolos

after_initialize do
   UserNotifications.class_eval do
   	def self.mailing_list_notify(user, post)
      send_notification_email(
        title: post.topic.title,
        post: post,
        from_alias: post.topic.category.name,
        allow_reply_by_email: true,
        notification_type: "posted",
        user: user
      )
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

    def self.send_notification_email(opts)
      post = opts[:post]
      title = opts[:title]
      allow_reply_by_email = opts[:allow_reply_by_email]
      from_alias = opts[:from_alias]
      notification_type = opts[:notification_type]
      user = opts[:user]

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

      #top = SiteContent.content_for(:notification_email_top)

      html = UserNotificationRenderer.new().render(
        file: '/plugins/sifhmail/app/views/email/notification',
        format: :html,
		#locals: { context_posts: context_posts, post: post }
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
        username: from_alias,
        add_unsubscribe_link: true,
        allow_reply_by_email: allow_reply_by_email,
        template: template,
        html_override: html,
        style: :notification
      }

      # If we have a display name, change the from address
      if from_alias.present?
        email_opts[:from_alias] = from_alias
      end

      TopicUser.change(user.id, post.topic_id, last_emailed_post_number: post.post_number)

      build_email(user.email, email_opts)
    end
  end
end
