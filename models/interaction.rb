class Interaction
  include MongoMapper::Document
  key :account_id, BSON::ObjectId
  key :bot_id, BSON::ObjectId
  key :user_id, String
  key :session_id, BSON::ObjectId
  key :platform, String
  key :time, Time
  key :user_input, String
  key :bot_rule, String
  key :lifetime_count, Integer
  key :bot_response
  timestamps!
  
  def self.divine_rules_for_bot_id(bot_id)
    account = Account.first(bot_ids: bot_id)
    Interaction.where(bot_id: bot_id).distinct(:bot_rule).each do |rule_name|
      interactions = Interaction.where(account_id: account.id, bot_id: bot_id, bot_rule: rule_name).to_a
      interactions.collect(&:platform).uniq.each do |platform|
        rule = Rule.first_or_create(name: rule_name, bot_id: bot_id, account_id: account.id, platform: platform)
        rule.topic ||= "random"
        rule.platform = platform
        rule.started_at ||= Time.now
        rule.ended_at = nil
        rule.interaction_count = interactions.count
        rule.save!
      end
    end;false
    bot = Bot.find(bot_id)
    bot.platforms_supported = Interaction.where(bot_id: bot_id).distinct(:platform)
    bot.save!
  end
end
#blacklist = UserBlacklist.first.blacklist
#Interaction.where(:user_id.in => blacklist).count
#TemporalEdge.where(:user_id.in => blacklist).count
#User.where(:user_id.in => blacklist).count
#UserSession.where(:user_id.in => blacklist).count