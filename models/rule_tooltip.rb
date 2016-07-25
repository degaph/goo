class RuleTooltip
  include MongoMapper::Document
  key :rule_id
  key :replies
  key :conditions
  key :previous
  key :dropped_interaction_count
  key :dropped_user_count
  key :not_dropped_interaction_count
  key :not_dropped_user_count
  key :dropped_typical_bot_responses
  key :dropped_typical_human_messages
  key :not_dropped_typical_bot_responses
  key :not_dropped_typical_human_messages
  key :average_length_dropped_conversations
  key :average_length_not_dropped_conversations
  key :dropped_interaction_count_all_platforms
  key :dropped_user_count_all_platforms
  key :not_dropped_interaction_count_all_platforms
  key :not_dropped_user_count_all_platforms
  key :dropped_typical_bot_responses_all_platforms
  key :dropped_typical_human_messages_all_platforms
  key :not_dropped_typical_bot_responses_all_platforms
  key :not_dropped_typical_human_messages_all_platforms
  key :average_length_dropped_conversations_all_platforms
  key :average_length_not_dropped_conversations_all_platforms

  def self.generate
    Rule.to_a.each do |rule|
      self.generate_by_rule(rule)
    end
  end
  
  def self.update_rule(rule_id)
    self.generate_by_rule(Rule.find(rule_id))
  end
  
  def self.generate_by_rule(rule)
    dropped_user_sessions = UserSession.where(last_rule_hit: rule.name, platform: rule.platform).to_a
    dropped_user_sessions_all_platforms = UserSession.where(last_rule_hit: rule.name).to_a
    dropped_interactions = Interaction.where(id: dropped_user_sessions.collect(&:last_interaction_id)).to_a;false
    dropped_interactions_all_platforms = Interaction.where(id: dropped_user_sessions_all_platforms.collect(&:last_interaction_id)).to_a;false
    not_dropped_interactions = Interaction.where(:id.nin => dropped_user_sessions.collect(&:last_interaction_id), account_id: rule.account_id, bot_id: rule.bot_id, bot_rule: rule.name, platform: rule.platform).to_a
    not_dropped_interactions_all_platforms = Interaction.where(:id.nin => dropped_user_sessions_all_platforms.collect(&:last_interaction_id), account_id: rule.account_id, bot_id: rule.bot_id, bot_rule: rule.name).to_a
    interaction_ids = not_dropped_interactions.collect(&:id)
    interaction_ids_all_platforms = not_dropped_interactions_all_platforms.collect(&:id)
    not_dropped_user_sessions = UserSession.where(:interactions => interaction_ids).to_a;false
    not_dropped_user_sessions_all_platforms = UserSession.where(:interactions => interaction_ids_all_platforms).to_a;false
    rt = RuleTooltip.first_or_create(rule_id: rule.id)
    rt.update_attributes!({
      replies: rule.reply, 
      conditions: rule.condition, 
      previous: rule.previous, 
      dropped_interaction_count: dropped_interactions.length, 
      dropped_user_count: dropped_interactions.collect{|x| x.user_id}.uniq.length, 
      not_dropped_interaction_count: not_dropped_interactions.length, 
      not_dropped_user_count: not_dropped_interactions.collect{|x| x.user_id}.uniq.length, 
      dropped_typical_bot_responses: dropped_interactions.shuffle.first(1000).collect(&:bot_response).collect{|i| i.collect{|x| x["text"]}.join("\n")}.counts.sort_by{|k,v| v}.reverse.first(10),
      dropped_typical_human_messages: dropped_interactions.shuffle.first(1000).collect(&:user_input).counts.sort_by{|k,v| v}.reverse.first(10),
      not_dropped_typical_bot_responses: not_dropped_interactions.shuffle.first(1000).collect(&:bot_response).collect{|i| i.collect{|x| x["text"]}.join("\n")}.counts.sort_by{|k,v| v}.reverse.first(10),
      not_dropped_typical_human_messages: not_dropped_interactions.shuffle.first(1000).collect(&:user_input).counts.sort_by{|k,v| v}.reverse.first(10),
      average_length_dropped_conversations: dropped_user_sessions.collect{|x| x.interactions.count}.average,
      average_length_not_dropped_conversations: not_dropped_user_sessions.collect(&:interactions).collect(&:length).average,
      dropped_interaction_count_all_platforms: dropped_interactions_all_platforms.length, 
      dropped_user_count_all_platforms: dropped_interactions_all_platforms.collect{|x| x.user_id}.uniq.length, 
      not_dropped_interaction_count_all_platforms: not_dropped_interactions_all_platforms.length, 
      not_dropped_user_count_all_platforms: not_dropped_interactions_all_platforms.collect{|x| x.user_id}.uniq.length, 
      dropped_typical_bot_responses_all_platforms: dropped_interactions_all_platforms.shuffle.first(1000).collect(&:bot_response).collect{|i| i.collect{|x| x["text"]}.join("\n")}.counts.sort_by{|k,v| v}.reverse.first(10),
      dropped_typical_human_messages_all_platforms: dropped_interactions_all_platforms.shuffle.first(1000).collect(&:user_input).counts.sort_by{|k,v| v}.reverse.first(10),
      not_dropped_typical_bot_responses_all_platforms: not_dropped_interactions_all_platforms.shuffle.first(1000).collect(&:bot_response).collect{|i| i.collect{|x| x["text"]}.join("\n")}.counts.sort_by{|k,v| v}.reverse.first(10),
      not_dropped_typical_human_messages_all_platforms: not_dropped_interactions_all_platforms.shuffle.first(1000).collect(&:user_input).counts.sort_by{|k,v| v}.reverse.first(10),
      average_length_dropped_conversations_all_platforms: dropped_user_sessions_all_platforms.collect{|x| x.interactions.count}.average,
      average_length_not_dropped_conversations_all_platforms: not_dropped_user_sessions_all_platforms.collect(&:interactions).collect(&:length).average
    })
    rt.save!
  end
  
  def self.generate_dynamic(rule_id, start_time, end_time, interaction_count_low, interaction_count_high)
    rule = Rule.find(rule_id)
    dropped_interaction_ids = UserSession.where(bot_id: rule.bot_id, platform: rule.platform, last_rule_hit: rule.name, :lifetime_count.gte => interaction_count_low, :lifetime_count.lte => interaction_count_high, :last_rule_time.gte => start_time, :last_rule_time.lte => end_time).distinct(:last_interaction_id)
    dropped_user_ids = UserSession.where(bot_id: rule.bot_id, platform: rule.platform, last_rule_hit: rule.name, :lifetime_count.gte => interaction_count_low, :lifetime_count.lte => interaction_count_high, :last_rule_time.gte => start_time, :last_rule_time.lte => end_time).distinct(:user_id)
    dropped_interaction_ids_all_platforms = UserSession.where(bot_id: rule.bot_id, last_rule_hit: rule.name, :lifetime_count.gte => interaction_count_low, :lifetime_count.lte => interaction_count_high, :last_rule_time.gte => start_time, :last_rule_time.lte => end_time).distinct(:last_interaction_id)
    dropped_user_ids_all_platforms = UserSession.where(bot_id: rule.bot_id, last_rule_hit: rule.name, :lifetime_count.gte => interaction_count_low, :lifetime_count.lte => interaction_count_high, :last_rule_time.gte => start_time, :last_rule_time.lte => end_time).distinct(:user_id)
    rt = RuleTooltip.new(rule_id: rule.id)
    rt.replies = rule.reply
    rt.conditions = rule.condition
    rt.previous = rule.previous
    rt.dropped_interaction_count = dropped_interaction_ids.count
    rt.dropped_user_count = dropped_user_ids.count
    rt.dropped_interaction_count_all_platforms = dropped_interaction_ids_all_platforms.count
    rt.dropped_user_count_all_platforms = dropped_user_ids_all_platforms.count
    invalid_bot_responses = ["[[typing]]", " ", ""]
    rt.not_dropped_interaction_count = Interaction.where(:id.nin => dropped_interaction_ids, account_id: rule.account_id, bot_id: rule.bot_id, bot_rule: rule.name, platform: rule.platform).count
    rt.not_dropped_interaction_count_all_platforms = Interaction.where(:id.nin => dropped_interaction_ids_all_platforms, account_id: rule.account_id, bot_id: rule.bot_id, bot_rule: rule.name).count
    rt.not_dropped_user_count = UserSession.where(bot_id: rule.bot_id, platform: rule.platform, :last_rule_hit.ne => rule.name, :lifetime_count.gte => interaction_count_low, :lifetime_count.lte => interaction_count_high, :last_rule_time.gte => start_time, :last_rule_time.lte => end_time).distinct(:user_id).count
    rt.not_dropped_user_count_all_platforms = UserSession.where(bot_id: rule.bot_id, :last_rule_hit.ne => rule.name, :lifetime_count.gte => interaction_count_low, :lifetime_count.lte => interaction_count_high, :last_rule_time.gte => start_time, :last_rule_time.lte => end_time).distinct(:user_id).count
    rt.dropped_typical_human_messages = CollectionHelper.match_and_group(Interaction, {"_id" => {"$in" => dropped_interaction_ids}, "bot_id" => rule.bot_id, "platform" => rule.platform, "bot_rule" => rule.name, "time" => {"$gte" => start_time, "$lte" => end_time}, "lifetime_count" => {"$gte" => interaction_count_low, "$lte" => interaction_count_high}}, {"_id" => {"user_input" => "$user_input"}, "count" => {"$sum" => 1}}).sort_by{|x| x["count"]}.collect{|x| [x["_id"]["user_input"], x["count"]]}.reject{|x| invalid_bot_responses.include?(x[0])}
    rt.dropped_typical_human_messages_all_platforms = CollectionHelper.match_and_group(Interaction, {"_id" => {"$in" => dropped_interaction_ids_all_platforms}, "bot_id" => rule.bot_id, "bot_rule" => rule.name, "time" => {"$gte" => start_time, "$lte" => end_time}, "lifetime_count" => {"$gte" => interaction_count_low, "$lte" => interaction_count_high}}, {"_id" => {"user_input" => "$user_input"}, "count" => {"$sum" => 1}}).sort_by{|x| x["count"]}.collect{|x| [x["_id"]["user_input"], x["count"]]}.reject{|x| invalid_bot_responses.include?(x[0])}
    rt.dropped_typical_bot_responses = CollectionHelper.match_and_group(Interaction, {"_id" => {"$in" => dropped_interaction_ids}, "bot_id" => rule.bot_id, "platform" => rule.platform, "bot_rule" => rule.name, "time" => {"$gte" => start_time, "$lte" => end_time}, "lifetime_count" => {"$gte" => interaction_count_low, "$lte" => interaction_count_high}}, {"_id" => {"bot_response" => "$bot_response"}, "count" => {"$sum" => 1}}).sort_by{|x| x["count"]}.collect{|x| [x["_id"]["bot_response"].class == String ? x["_id"]["bot_response"] : x["_id"]["bot_response"].collect{|x| x["text"]}.join("\n"), x["count"]]}.reject{|x| invalid_bot_responses.include?(x[0])}
    rt.dropped_typical_bot_responses_all_platforms = CollectionHelper.match_and_group(Interaction, {"_id" => {"$in" => dropped_interaction_ids_all_platforms}, "bot_id" => rule.bot_id, "bot_rule" => rule.name, "time" => {"$gte" => start_time, "$lte" => end_time}, "lifetime_count" => {"$gte" => interaction_count_low, "$lte" => interaction_count_high}}, {"_id" => {"bot_response" => "$bot_response"}, "count" => {"$sum" => 1}}).sort_by{|x| x["count"]}.collect{|x| [x["_id"]["bot_response"].class == String ? x["_id"]["bot_response"] : x["_id"]["bot_response"].collect{|x| x["text"]}.join("\n"), x["count"]]}.reject{|x| invalid_bot_responses.include?(x[0])}
    rt.not_dropped_typical_human_messages = CollectionHelper.match_and_group(Interaction, {"_id" => {"$nin" => dropped_interaction_ids}, "bot_id" => rule.bot_id, "platform" => rule.platform, "bot_rule" => rule.name, "time" => {"$gte" => start_time, "$lte" => end_time}, "lifetime_count" => {"$gte" => interaction_count_low, "$lte" => interaction_count_high}}, {"_id" => {"user_input" => "$user_input"}, "count" => {"$sum" => 1}}).sort_by{|x| x["count"]}.collect{|x| [x["_id"]["user_input"], x["count"]]}.reject{|x| invalid_bot_responses.include?(x[0])}
    rt.not_dropped_typical_human_messages_all_platforms = CollectionHelper.match_and_group(Interaction, {"_id" => {"$nin" => dropped_interaction_ids_all_platforms}, "bot_id" => rule.bot_id, "bot_rule" => rule.name, "time" => {"$gte" => start_time, "$lte" => end_time}, "lifetime_count" => {"$gte" => interaction_count_low, "$lte" => interaction_count_high}}, {"_id" => {"user_input" => "$user_input"}, "count" => {"$sum" => 1}}).sort_by{|x| x["count"]}.collect{|x| [x["_id"]["user_input"], x["count"]]}.reject{|x| invalid_bot_responses.include?(x[0])}
    rt.not_dropped_typical_bot_responses = CollectionHelper.match_and_group(Interaction, {"_id" => {"$nin" => dropped_interaction_ids}, "bot_id" => rule.bot_id, "platform" => rule.platform, "bot_rule" => rule.name, "time" => {"$gte" => start_time, "$lte" => end_time}, "lifetime_count" => {"$gte" => interaction_count_low, "$lte" => interaction_count_high}}, {"_id" => {"bot_response" => "$bot_response"}, "count" => {"$sum" => 1}}).sort_by{|x| x["count"]}.collect{|x| [x["_id"]["bot_response"].class == String ? x["_id"]["bot_response"] : x["_id"]["bot_response"].collect{|x| x["text"]}.join("\n"), x["count"]]}.reject{|x| invalid_bot_responses.include?(x[0])}
    rt.not_dropped_typical_bot_responses_all_platforms = CollectionHelper.match_and_group(Interaction, {"_id" => {"$nin" => dropped_interaction_ids_all_platforms}, "bot_id" => rule.bot_id, "bot_rule" => rule.name, "time" => {"$gte" => start_time, "$lte" => end_time}, "lifetime_count" => {"$gte" => interaction_count_low, "$lte" => interaction_count_high}}, {"_id" => {"bot_response" => "$bot_response"}, "count" => {"$sum" => 1}}).sort_by{|x| x["count"]}.collect{|x| [x["_id"]["bot_response"].class == String ? x["_id"]["bot_response"] : x["_id"]["bot_response"].collect{|x| x["text"]}.join("\n"), x["count"]]}.reject{|x| invalid_bot_responses.include?(x[0])}
    rt.average_length_dropped_conversations = UserSession.collection.aggregate([{"$match" => {"bot_id" => rule.bot_id, "platform" => rule.platform, "last_rule_hit" => rule.name, "last_rule_time" => {"$gte" => start_time, "$lte" => end_time}, "lifetime_count" => {"$gte" => interaction_count_low, "$lte" => interaction_count_high}}}, {"$project" => {"_id" => "$id", "length" => {"$size" => "$interactions"}}}]).collect{|x| x["length"]}.average
    rt.average_length_dropped_conversations_all_platforms = UserSession.collection.aggregate([{"$match" => {"bot_id" => rule.bot_id, "last_rule_hit" => rule.name, "last_rule_time" => {"$gte" => start_time, "$lte" => end_time}, "lifetime_count" => {"$gte" => interaction_count_low, "$lte" => interaction_count_high}}}, {"$project" => {"_id" => "$id", "length" => {"$size" => "$interactions"}}}]).collect{|x| x["length"]}.average
    rt.average_length_not_dropped_conversations = UserSession.collection.aggregate([{"$match" => {"bot_id" => rule.bot_id, "platform" => rule.platform, "last_rule_hit" => {"$ne" => rule.name}, "last_rule_time" => {"$gte" => start_time, "$lte" => end_time}, "lifetime_count" => {"$gte" => interaction_count_low, "$lte" => interaction_count_high}}}, {"$project" => {"_id" => "$id", "length" => {"$size" => "$interactions"}}}]).collect{|x| x["length"]}.average
    rt.average_length_not_dropped_conversations_all_platforms = UserSession.collection.aggregate([{"$match" => {"bot_id" => rule.bot_id, "last_rule_hit" => {"$ne" => rule.name}, "last_rule_time" => {"$gte" => start_time, "$lte" => end_time}, "lifetime_count" => {"$gte" => interaction_count_low, "$lte" => interaction_count_high}}}, {"$project" => {"_id" => "$id", "length" => {"$size" => "$interactions"}}}]).collect{|x| x["length"]}.average
    rt
  end
end