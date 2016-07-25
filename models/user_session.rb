class UserSession
  include MongoMapper::Document
  key :platform, String
  key :user_id, String
  key :bot_id, BSON::ObjectId
  key :first_rule_hit, String
  key :first_rule_time, Time
  key :last_rule_hit, String
  key :last_rule_time, Time
  key :last_messsage_at, Time
  key :last_interaction_id, BSON::ObjectId
  key :lifetime_count, Integer
  key :interactions, Array
  key :bot_rules, Array
  key :first_user_time, Time
  timestamps!
end
#UserSession.to_a.collect{|x| first = Interaction.find(x.interactions.first); x.first_rule_hit = first.bot_rule; x.first_rule_time = first.time;x.save;print "."}