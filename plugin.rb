# name: DiscourseEmailIncludeAddress
# about: Add email address to notifications
# version: 0.1
# authors: pfaffman
# url: https://github.com/pfaffman/discourse-email-include-address

# NOTE: There isn't really a way to disable this plugin

enabled_site_setting :discourse_email_include_address_enabled

Rails.configuration.paths["app/views"].unshift(File.expand_path("../templates", __FILE__))
