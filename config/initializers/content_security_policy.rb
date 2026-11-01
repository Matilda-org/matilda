# Be sure to restart your server when you modify this file.

# Content Security Policy: defense in depth against XSS. Scripts run only from
# this origin, the pinned CDNs and inline blocks carrying the per-request nonce
# (importmap and javascript_tag nonce: true add it). Inline styles stay allowed:
# views and Bootstrap/Trix set style attributes.
# See https://guides.rubyonrails.org/security.html#content-security-policy-header

Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :self
    policy.base_uri    :self
    policy.form_action :self
    policy.frame_ancestors :none
    policy.object_src  :none
    policy.script_src  :self, "https://ga.jspm.io", "https://cdn.jsdelivr.net", "https://unpkg.com"
    policy.style_src   :self, :unsafe_inline, "https://fonts.googleapis.com", "https://cdn.jsdelivr.net", "https://unpkg.com"
    policy.font_src    :self, :data, "https://fonts.gstatic.com", "https://cdn.jsdelivr.net"
    policy.img_src     :self, :data, :blob, :https
    policy.media_src   :self, :data, :blob, :https
    policy.connect_src :self, :wss, "https://ga.jspm.io"
    policy.frame_src   :self
    policy.worker_src  :self
  end

  config.content_security_policy_nonce_generator = ->(request) { SecureRandom.base64(16) }
  config.content_security_policy_nonce_directives = %w[script-src]
end
