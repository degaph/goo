class UpdateInteractions
  include Sidekiq::Worker
  sidekiq_options :queue => :cyrano_updates
  def perform(user_id, bot_id, platform)
    count = Interaction.count(user_id: user_id, bot_id: BSON::ObjectId(bot_id), platform: platform)
    Interaction.set({user_id: user_id, bot_id: BSON::ObjectId(bot_id), platform: platform}, {lifetime_count: count})
    UserSession.set({user_id: user_id, bot_id: BSON::ObjectId(bot_id), platform: platform}, {lifetime_count: count})
    User.set({user_id: user_id, bot_id: BSON::ObjectId(bot_id), platform: platform}, {lifetime_count: count})
    TemporalEdge.set({user_id: user_id, bot_id: BSON::ObjectId(bot_id), platform: platform}, {lifetime_count: count})
  end
end