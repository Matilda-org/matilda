class SlackService
  def initialize
    @token = Setting.get("slack_bot_user_oauth_token")
    @is_valid = !!@token
  end

  def find_user_id(name, surname)
    return false unless @is_valid

    response = RestClient.post("https://slack.com/api/users.list", token: @token, limit: 100)
    response_json = JSON.parse(response)

    return false unless response_json["ok"]

    user_id = nil
    response_json["members"].each do |slack_member|
      next unless (slack_member["profile"]["first_name"]&.downcase == name.downcase && slack_member["profile"]["last_name"]&.downcase == surname.downcase) || slack_member["real_name"]&.downcase == "#{name} #{surname}".downcase

      user_id = slack_member["id"]
      break
    end

    user_id
  rescue StandardError => e
    Rails.logger.error e
    false
  end

  def create_channel(name, index = 0)
    return false unless @is_valid

    final_name = name.downcase.parameterize
    final_name = "#{final_name}-#{index}" if index > 0
    response = RestClient.post("https://slack.com/api/conversations.create", token: @token, name: final_name)
    response_json = JSON.parse(response)

    unless response_json["ok"]
      return create_channel(name, index + 1) if response_json["error"] == "name_taken"

      return false
    end

    response_json["channel"]
  rescue StandardError => e
    Rails.logger.error e
    false
  end

  def rename_channel(channel_id, name, index = 0)
    return false unless @is_valid

    final_name = name.downcase.parameterize
    final_name = "#{final_name}-#{index}" if index > 0
    response = RestClient.post("https://slack.com/api/conversations.rename", token: @token, channel: channel_id, name: final_name)
    response_json = JSON.parse(response)

    unless response_json["ok"]
      return rename_channel(channel_id, name, index + 1) if response_json["error"] == "name_taken"

      return false
    end

    response_json["channel"]
  rescue StandardError => e
    Rails.logger.error e
    false
  end

  def archive_channel(channel_id)
    return false unless @is_valid

    response = RestClient.post("https://slack.com/api/conversations.archive", token: @token, channel: channel_id)
    response_json = JSON.parse(response)

    return false unless response_json["ok"]

    true
  rescue StandardError => e
    Rails.logger.error e
    false
  end

  def invite_member_to_channel(channel_id, slack_user_id)
    return false unless @is_valid

    response = RestClient.post("https://slack.com/api/conversations.invite", token: @token, channel: channel_id, users: slack_user_id)
    response_json = JSON.parse(response)

    return false unless response_json["ok"]

    true
  rescue StandardError => e
    Rails.logger.error e
    false
  end

  def remove_member_from_channel(channel_id, slack_user_id)
    return false unless @is_valid

    response = RestClient.post("https://slack.com/api/conversations.kick", token: @token, channel: channel_id, user: slack_user_id)
    response_json = JSON.parse(response)

    return false unless response_json["ok"]

    true
  rescue StandardError => e
    Rails.logger.error e
    false
  end

  def post_message_to_channel(channel_id, message)
    return false unless @is_valid

    response = RestClient.post("https://slack.com/api/chat.postMessage", token: @token, channel: channel_id, text: message)
    response_json = JSON.parse(response)

    return false unless response_json["ok"]

    true
  rescue StandardError => e
    Rails.logger.error e
    false
  end
end
