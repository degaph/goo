class Simulator
  def self.parse_log_file(filepath="/home/ubuntu/poncho_chat_logs_new.txt", account_id=Account.first.id, bot_id=Bot.first.id)
    parsed_interactions = []
    File.read(filepath).each_line do |log|
      parsed_interactions << self.parse_interaction(JSON.parse(log), account_id, bot_id)
      if !parsed_interactions.last.nil? && Rule.first(name: parsed_interactions.last[:bot_rule]).nil?
      rule = Rule.first_or_create(account_id: account_id, bot_id: bot_id, condition: [], name: parsed_interactions.last[:bot_rule], platform: "facebook", previous: [], reply: parsed_interactions.last[:bot_response], topic: "random")
      end
    end;false
    parsed_interactions
  end
  
  def self.parse_interaction(parsed_log, account_id, bot_id)
    return nil if parsed_log["platform"]["s"] == "hack-facebook" || !parsed_log["chat_token"]["s"].to_s.include?("facebook") || parsed_log["matched_on"].keys.include?("nULL")
    {
      account_id: account_id,
      bot_id: bot_id,
      user_id: parsed_log["chat_token"]["s"],
      platform: parsed_log["platform"]["s"],
      time: Time.at(parsed_log["epoch_in_ms"]["n"].to_f/1000),
      user_input: parsed_log["user_input"]["s"],
      bot_rule: parsed_log["matched_on"]["s"],
      bot_response: JSON.parse(parsed_log["reply"]["s"])
    }
  end
  
  def self.process_poncho
    Simulator.parse_log_file.compact.sort_by{|i| i[:time]}.each do |interaction|
      ProcessInteraction.perform_async(interaction)
    end;false
  end
  
  def self.refresh
    [Account, Bot, Edge, Interaction, Node, RiveManifestUpdate, RiveManifest, RuleTooltip, Rule, TemporalEdge, TemporalStats, UserBlacklist, UserSession, User].collect(&:collection).collect(&:drop)
    Sidekiq::Queue.new("cyrano_logger").clear
    Sidekiq::Queue.new("cyrano_updates").clear
    TemporalEdge.ensure_index([[:account_id, 1], [:bot_id, 1], [:platform, 1], [:rule_source, 1]])
    Rule.ensure_index(:name)
    TemporalEdge.ensure_index([[:user_id, 1], [:bot_id, 1], [:platform, 1]])
    Interaction.ensure_index([[:user_id, 1], [:bot_id, 1], [:platform, 1]])
    Interaction.ensure_index([[:user_id, 1], [:bot_id, 1], [:platform, 1], [:time, 1]])
    User.ensure_index([[:user_id, 1], [:bot_id, 1], [:platform, 1]])
    UserSession.ensure_index([[:user_id, 1], [:bot_id, 1], [:platform, 1], [:last_message_at, 1]])
    Interaction.ensure_index([[:id, 1], [:account_id, 1], [:bot_id, 1], [:bot_rule, 1], [:platform, 1]])
    UserSession.ensure_index([[:last_rule_hit, 1], [:lifetime_count, 1], [:last_rule_time, 1], [:bot_id, 1], [:platform, 1]])
    TemporalEdge.ensure_index([[:lifetime_count, 1], [:occurred_at, 1], [:account_id, 1], [:bot_id, 1], [:platform, 1], [:rule_source, 1]])
    Account.account_onboard("poncho", "poncho_app", ["facebook"])
    RiveManifest.ingest("/home/ubuntu/complete-staging.rive", Bot.first.id, "facebook")
    ub = UserBlacklist.new
    ub.bot_id = Bot.first.id
    Bot.count
    ub.platform = "facebook"
    ub.blacklist = ["facebook-dXNlcjpBZAVJmYTFwMUtJQnNkQ2NFMV8zcWtqaUpXanBxS0VVZAHJXdmppMTNBM0duQjhyRDJrNEVUaUJiWEZAHWXVVemotUDlqR0U3cE92djR5azlJN19SX0F3ODNuOXE3SjNYSnRZAVlJkblpZAV0JMWGVKdwZDZD",
    "facebook-dXNlcjpBZAVNoaTdfdjlaUXYxQmFfRHRaMTBhWG5PRlJhbVdJLWEzMzFoN2hHTkVhLVREaU9zWmJJQW1pQzF3SVN6R053b2R5djdUalRTT0FoVm5JRVA4LU1VSEhJUlhBdlk3bndHNjJpNDh3RW42Q0sxZAwZDZD",
    "facebook-dXNlcjpBZAVFqLXUyX0RwRGxZAYnN5NWM1MTVqRWNwVzIzWTE1cE8xQ21CcmVhUUkwVUZAxTzdTa2stN3lNaG5TR1JVdVdUSjJ3Y0ZA3WVdSR0pmZAHNmLWRBZAVpuSTZABUHhTOFlWaDQ1SVY1WUlXdzd1MHNGUQZDZD",
    "facebook-dXNlcjpBZAVRmWkJ1dlg5VzZA6T01ZAM1ZABTnZAxWmxDZAkdGaFM1RTFSN3FtRlJVR1dacXBmMFVRMTlTNi01Sy1tMWNZAclpoTzVrUWJNcnpBcXc4aXY3bXpUelFwNjFLT3N4WGMtbkhubExjbjV5VFMxUVVudwZDZD",
    "facebook-dXNlcjpBZAVJFblpJU1FqZADU3SzFjaWdmbGhJdngwUGNOU3JPZAlJHQ3lFMlFCT3JYcGpwWHMwd3NHbU95VUpuYWlvNWotMUNiempXQlBNV2xzdU9GZATJzZAXBpZAk5IRWtiVUdyMmtBNjJqeDB2MVlqQWtkdwZDZD",
    "facebook-dXNlcjpBZAVRlUmQ1c0VXYmFFWF9QT3RnSGxrQmpLTklPYmtnVHJ5NkdzZA3ZADdmVGSC1Eem5JX3cxTjNVb2RZAT2ZAHOHBCWUQwWC1jMHZAjcFlOWTl1ZAmdjSFFybTJfRHpyb081RVh4UnFwZAHd2T29XWmRmdwZDZD"]
    ub.save!
    Simulator.process_poncho
  end
  
  def onboard_super_admin
    au = AccountUser.first_or_create(first_name: "Devin", last_name: "Gaffney", email: "itsme@devingaffney.com")
    au.password = "gabagool"
    au.account_ids = Account.to_a.collect(&:id)
    au.save!
  end
end
Simulator.refresh


#[Edge, Interaction, Node, Rule, TemporalEdge, UserSession, User].collect{|x| x.collection.drop}
#=> #<Rule _id: BSON::ObjectId('5768350a17a6e90817000161'), account_id: BSON::ObjectId('5764355e17a6e9faf1000003'), bot_id: BSON::ObjectId('5764354317a6e9faf1000002'), condition: [], created_at: 2016-06-20 18:25:14 UTC, name: "fuzzybot do location was saved", platform: "facebook", previous: [], reply: [{"reply_content"=>"<call>locationWasSaved</call>", "started_at"=>2016-06-20 18:25:14 UTC}], topic: "user_unregistered", updated_at: 2016-06-20 18:25:14 UTC> 




#au = AccountUser.first_or_create(first_name: "Greg", last_name: "Leuch", email: "greg@betaworks.com")
#au.account_ids = [BSON::ObjectId("577ee2908b1ef759ba000001")]
#account = Account.find(BSON::ObjectId("577ee2908b1ef759ba000001"))
#au.save
#au.send_reset_email(true)
#account.admin_ids << au.id
#account.account_user_ids << au.id
#account.save!
#
#au = AccountUser.first_or_create(first_name: "Roy", last_name: "Pereira", email: "roy@zoom.ai")
#au.account_ids = [BSON::ObjectId("5785179f8b1ef71692000004")]
#account = Account.find(BSON::ObjectId("5785179f8b1ef71692000004"))
#au.save
#au.send_reset_email(true)
#account.admin_ids << au.id
#account.account_user_ids << au.id
#account.save!
#
#
# au = AccountUser.first_or_create(first_name: "Gilad", last_name: "Lotan", email: "gilad@betaworks.com")
# au.send_reset_email(true)
# au.account_ids = [BSON::ObjectId("577ee2908b1ef759ba000001"), BSON::ObjectId("5785179f8b1ef71692000004")]
# Account.each do |a|
#   a.admin_ids << au.id
#   a.save!
# end