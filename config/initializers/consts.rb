APPLICATION_VERSION = "3.46.16"

APPLICATION_MAIL_FROM = ENV["MATILDA_MAIL_FROM"] || Rails.application.credentials.dig(:matilda, :mail_from) || "Matilda <noreply@mail.com>"
APPLICATION_HOST = ENV["MATILDA_HOST"] || Rails.application.credentials.dig(:matilda, :host) || "matilda.local"
