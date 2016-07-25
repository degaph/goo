class User
  include MongoMapper::Document
  key :platform, String
  key :user_id, String
  key :bot_id, BSON::ObjectId
  key :first_interaction_id, BSON::ObjectId
  key :first_rule_hit, String
  key :first_rule_time, Time
  key :last_rule_hit, String
  key :last_rule_time, Time
  key :last_interaction_id, BSON::ObjectId
  key :lifetime_count, Integer
  key :sessions, Array
  timestamps!
end

# User.all.each do |user|
#  first_interaction = Interaction.order(:time).first(user_id: user.user_id, :lifetime_count.ne => nil)
#  user.first_interaction_id = first_interaction.id
#  user.first_rule_hit = first_interaction.bot_rule
#  user.first_rule_time = first_interaction.time
#  user.lifetime_count = first_interaction.lifetime_count
#  user.save!
# end
# Interaction.where(:lifetime_count => nil).each do |interaction|
#   interaction.lifetime_count = Interaction.count(user_id: interaction.user_id)
#   interaction.save!
# end
# UserSession.where(:lifetime_count => nil).each do |user_session|
#   user_session.lifetime_count = Interaction.count(user_id: user_session.user_id)
#   user_session.save!
# end
# TemporalEdge.where(:lifetime_count => nil).each do |temporal_edge|
#   temporal_edge.lifetime_count = Interaction.count(user_id: temporal_edge.user_id)
#   temporal_edge.save!
# end
# User.where(:lifetime_count => nil).each do |user|
#   user.lifetime_count = Interaction.count(user_id: user.user_id)
#   user.save!
# end