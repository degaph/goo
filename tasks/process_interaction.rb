class ProcessInteraction
  include Sidekiq::Worker
  sidekiq_options :queue => :cyrano_logger
  def perform(interaction)
   account = nil
   bot = nil
     if interaction["account_name"] && interaction["bot_name"]
       account = Account.first(account_name: interaction["account_name"])
       bot = Bot.first(bot_name: interaction["bot_name"], account_id: account.id)
     else
       account = Account.find(BSON::ObjectId(interaction["account_id"]))
       bot = Bot.find(BSON::ObjectId(interaction["bot_id"]))
     end
    return nil if UserBlacklist.where(bot_id: bot.id, platform: interaction["platform"]).first && UserBlacklist.where(bot_id: bot.id, platform: interaction["platform"]).first.blacklist.include?(interaction["user_id"])
    previous_interaction = Interaction.where(user_id: interaction["user_id"], bot_id: bot.id, platform: interaction["platform"]).order(:time.desc).first
    UpdateInteractions.perform_async(interaction["user_id"], bot.id, interaction["platform"])
    interaction["bot_id"] = bot.id
    interaction["account_id"] = account.id
    interaction = Interaction.new(interaction)
    interaction.save
    user = User.first_or_create(user_id: interaction["user_id"], bot_id: bot.id, platform: interaction["platform"])
    if user.first_rule_hit.nil?
      user.first_rule_hit = interaction["bot_rule"]
      user.first_rule_time = Time.parse(interaction["time"].to_s)
      user.first_interaction_id = interaction.id
      user.sessions = []
    end
    user.last_rule_hit = interaction["bot_rule"]
    user.last_rule_time = Time.parse(interaction["time"].to_s)
    user.last_interaction_id = interaction.id
    user_session = UserSession.first(user_id: interaction["user_id"], bot_id: bot.id, platform: interaction["platform"], :last_message_at.gte => Time.parse(interaction["time"].to_s)-15.minutes) || UserSession.new(user_id: interaction["user_id"], bot_id: bot.id, platform: interaction["platform"], last_message_at: Time.parse(interaction["time"].to_s))
    user_session.save
    user_session.interactions << interaction.id
    user_session.bot_rules << interaction.bot_rule
    user_session.first_rule_hit = interaction["bot_rule"] if user_session.interactions.length == 1
    user_session.first_rule_time = Time.parse(interaction["time"].to_s) if user_session.interactions.length == 1
    user_session.last_rule_hit = interaction["bot_rule"]
    user_session.last_rule_time = Time.parse(interaction["time"].to_s)
    user_session.last_interaction_id = interaction.id
    user_session.first_user_time = user.first_rule_time
    user_session.save
    interaction.session_id = user_session.id
    interaction.save!
    user.sessions << user_session.id
    user.save
    if previous_interaction
      te = TemporalEdge.new(
        user_id: interaction["user_id"], 
        rule_source_session: previous_interaction.session_id, 
        rule_target_session: interaction.session_id, 
        rule_source: previous_interaction.bot_rule, 
        rule_target: interaction["bot_rule"], 
        occurred_at: Time.parse(interaction["time"].to_s), 
        bot_id: bot.id, 
        platform: interaction["platform"], 
        account_id: account.id, 
        interevent_time: Time.parse(interaction["time"].to_s)-previous_interaction.time
      )
      te.save
    end
    rule = Rule.first(name: interaction["bot_rule"])
  end
end

#Interaction.where(bot_id: @bot.id).each do |interaction|
#  UpdateInteractions.perform_async(interaction.user_id, interaction.bot_id, interaction.platform)
#end
#UserSession.all.each do |user_session|
#user_session.bot_rules = user_session.interactions.collect{|x| Interaction.find(x).bot_rule}
#user_session.save!
#end
