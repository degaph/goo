#def get_deep_dive
#  @rule = Rule.first(id: params[:rule_id])
#  @bot = Bot.first(id: @rule.bot_id)
#  ta = TemporalAggregator.new(@interaction_count_low, @interaction_count_high, @start_time, @end_time)
#  @rule_tooltip = RuleTooltip.generate_dynamic(BSON::ObjectId(params[:rule_id]), @start_time, @end_time, @interaction_count_low, @interaction_count_high)
#  @session_drops = ta.session_drops({last_rule_hit: @rule.name}).count
#  @interactions = ta.interactions({bot_rule: @rule.name}).count
#  @interactions_timeline = ta.interactions_timeline({"bot_rule" => @rule.name})
#  @session_drops_timeline = ta.session_drops_timeline({"last_rule_hit" => @rule.name})
#  dropped = Hash[@rule_tooltip.dropped_typical_bot_responses.collect{|k,v| [k,v.to_f/@rule_tooltip.dropped_user_count]}]
#  not_dropped = Hash[@rule_tooltip.not_dropped_typical_bot_responses.collect{|k,v| [k,v.to_f/@rule_tooltip.not_dropped_user_count]}]
#  @should_change = dropped.collect{|k,v| [k,v-not_dropped[k]] if not_dropped[k]}.compact.sort_by{|k,v| v}.reverse
#  @total_count = ta.total_count({account_id: @rule.account_id, bot_id: @rule.bot_id, platform: @rule.platform, rule_source: @rule.name})
#  @next_step = ta.next_step({account_id: @rule.account_id, bot_id: @rule.bot_id, platform: @rule.platform, rule_source: @rule.name}, @total_count)
#  @rule_id_map = Hash[Rule.where(account_id: @rule.account_id, bot_id: @rule.bot_id, platform: @rule.platform).fields(:_id, :name).collect{|r| [r.name, r.id] if @next_step.keys.include?(r.name)}.compact]
#  @rules = Hash[Rule.where(id: @rule_id_map.values).to_a.collect{|x| [x.id, x]}]
#  next_dropped_interaction_counts = 
#  next_interaction_counts = Hash[Interaction.collection.aggregate([{"$match" => {"bot_id" => @rule.bot_id, "platform" => @rule.platform, "bot_rule" => {"$in" => @next_step.keys}, "time" => {"$gte" => @start_time, "$lte" => @end_time}, "lifetime_count" => {"$gte" => @interaction_count_low, "$lte" => @interaction_count_high}}}, {"$group" => {"_id" => "$bot_rule", "count" => {"$sum" => 1}}}]).collect{|x| [x["_id"], x["count"]]}];false
#  @next_risks = Hash[@rule_id_map.keys.collect{|rule| [rule, (next_dropped_interaction_counts[rule]||0)/((next_dropped_interaction_counts[rule]||0)+(next_interaction_counts[rule]||0)).to_f]}]
#  @next_risks.keys.collect{|k| @next_risks[k] = 0 if @next_risks[k].nan?}
#  @merged_timeline = CollectionHelper.merge_timelines({"Sessions" => @session_drops_timeline, "Interactions" => @interactions_timeline})
#  erb :"deep_dive"
#end
#class TemporalAggregator
#  def initialize(interaction_count_low, interaction_count_high, start_time, end_time)
#    @interaction_count_low = interaction_count_low
#    @interaction_count_high = interaction_count_high
#    @start_time = start_time
#    @end_time = end_time
#  end
#
#  def basic_temporal_activity_query(context)
#    if context == "session_drops"
#      {:lifetime_count.gte => @interaction_count_low, :lifetime_count.lte => @interaction_count_high, :last_rule_time.gte => @start_time, :last_rule_time.lte => @end_time}
#    elsif context == "interactions"
#      {:lifetime_count.gte => @interaction_count_low, :lifetime_count.lte => @interaction_count_high, :time.gte => @start_time, :time.lte => @end_time}
#    elsif context == "interactions_timeline"
#      {"lifetime_count" => {"$gte" => @interaction_count_low, "$lte" => @interaction_count_high}, "time" => {"$gte" => @start_time, "$lte" => @end_time}}
#    elsif context == "session_drops_timeline"
#      {"lifetime_count" => {"$gte" => @interaction_count_low, "$lte" => @interaction_count_high}, "last_rule_time" => {"$gte" => @start_time, "$lte" => @end_time}}
#    elsif context == "total_count"
#      {:lifetime_count.gte => @interaction_count_low, :lifetime_count.lte => @interaction_count_high, :occurred_at.gte => @start_time, :occurred_at.lte => @end_time}
#    elsif context == "next_step"
#      {"lifetime_count" => {"$gte" => @interaction_count_low, "$lte" => @interaction_count_high}, "occurred_at" => {"$gte" => @start_time, "$lte" => @end_time}}
#    end
#  end
#
#  def basic_temporal_activity_group_operations(context)
#    if context == "interactions_timeline"
#      {"_id" => {"day" => {"$dayOfMonth" => "$time"}, "month" => {"$month" => "$time"}, "year" => {"$year" => "$time"}}, "count" => {"$sum" => 1}}
#    elsif context == "session_drops_timeline"
#      {"_id" => {"day" => {"$dayOfMonth" => "$last_rule_time"}, "month" => {"$month" => "$last_rule_time"}, "year" => {"$year" => "$last_rule_time"}}, "count" => {"$sum" => 1}}
#    elsif context == "next_step"
#      {"_id" => {"rule_target" => "$rule_target"}, "count" => {"$sum" => 1}}
#    end
#  end
#
#  def basic_temporal_activity_reductions(context, object)
#    if context == "interactions_timeline" || context == "session_drops_timeline"
#      [Time.parse(x["_id"]["year"].to_s+"-"+x["_id"]["month"].to_s+"-"+x["_id"]["day"].to_s+" 00:00:00"), x["count"]]
#    elsif context == "next_step"
#      [x["_id"]["rule_target"], x["count"]/x[:total_count] > 1 ? 1.00 : x["count"]/x[:total_count]]
#    end
#  end
#
#  def session_drops(extra_conditions={})
#    UserSession.where(basic_temporal_activity_query("session_drops").merge(extra_conditions)).count
#  end
#
#  def interactions(extra_conditions={})
#    Interaction.where(basic_temporal_activity_query("interactions").merge(extra_conditions)).count
#  end
#
#  def interactions_timeline(extra_conditions={})
#    Hash[CollectionHelper.match_and_group(Interaction, basic_temporal_activity_query("interactions_timeline").merge(extra_conditions)}, basic_temporal_activity_group_operations("interactions_timeline")).collect{|x| basic_temporal_activity_reductions("interactions_timeline", x)]}]
#  end
#    
#  def session_drops_timeline(extra_conditions={})
#    Hash[CollectionHelper.match_and_group(UserSession, basic_temporal_activity_query("session_drops_timeline").merge(extra_conditions)}, basic_temporal_activity_group_operations("session_drops_timeline")).collect{|x| basic_temporal_activity_reductions("session_drops_timeline", x)]}]
#  end
#  
#  def total_count(extra_conditions={})
#    TemporalEdge.where(basic_temporal_activity_query("session_drops_timeline")).count.to_f
#  end
#  
#  def next_step(extra_conditions={}, total_count)
#    Hash[CollectionHelper.match_and_group(basic_temporal_activity_query("next_step").merge(extra_conditions), basic_temporal_activity_group_operations("next_step")).collect{|x| x[:total_count] = total_count;basic_temporal_activity_reductions(context, x)}]
#  end
#  
#  def next_dropped_interaction_counts(extra_conditions={})
#  CollectionHelper.match_and_group(basic_temporal_activity_query("next_dropped_interaction_counts").merge(extra_conditions))
#    Hash[UserSession.collection.aggregate([{"$match" => {"bot_id" => @rule.bot_id, "platform" => @rule.platform, "last_rule_hit" => {"$in" => @next_step.keys}, "last_rule_time" => {"$gte" => @start_time, "$lte" => @end_time}, "lifetime_count" => {"$gte" => @interaction_count_low, "$lte" => @interaction_count_high}}}, {"$group" => {"_id" => "$last_rule_hit", "count" => {"$sum" => 1}}}]).collect{|x| [x["_id"], x["count"]]}];false
#  end
#end

#get "/network/latest/:bot_id.json" do
#  convo_lengths = UserSession.collection.aggregate([{"$match" => {bot_id: BSON::ObjectId(params[:bot_id])}}, {"$project" => {"length" => {"$size" => "$interactions"}}}]).collect{|us| us["length"]}
#  user_session_lengths = UserSession.where(bot_id: BSON::ObjectId(params[:bot_id])).distinct(:user_id)
#  user_session_exit_counts = Hash[UserSession.collection.aggregate([{"$match" => {bot_id: BSON::ObjectId(params[:bot_id])}}, {"$group" => {"_id" => {"last_rule_hit" => "$last_rule_hit"}, "count" => {"$sum" => 1}}}]).collect{|us| [us["_id"]["last_rule_hit"], us["count"]]}]
#  nodes = []
#  Rule.where(bot_id: BSON::ObjectId(params[:bot_id])).to_a.collect{|r| nodes << {label: r.name, rule_id: r.id.to_s} if !nodes.collect{|x| x[:label]}.include?(r.name)}
#  node_names = nodes.collect{|x| x[:label]}
#  weights = {}
#  raw_edges = TemporalEdge.collection.aggregate([{"$match" => {"bot_id" => BSON::ObjectId(params[:bot_id])}}, {"$group" =>{"_id" => {"bot_id" => "$bot_id", "platform" => "$platform", "rule_source" => "$rule_source", "rule_target" => "$rule_target"}, "count" => { "$sum" => 1 }}}])
#  #raw_edges.collect{|re| [re["_id"]["rule_source"], re["_id"]["rule_target"]]}.flatten.uniq.collect{|x| (nodes << {label: x}; node_names << x) if !node_names.include?(x)}
#  raw_edges.collect{|re| weights[re["_id"]["rule_target"]] ||= 0 ; weights[re["_id"]["rule_target"]] += re["count"]}
#  final_nodes = nodes.collect{|x| x[:rule_id] = x[:rule_id] ; x[:id] = node_names.index(x[:label]); x[:size] = Math.log((weights[x[:label]]||1)+10)*10; x[:loss] = (((user_session_exit_counts[x[:label]] || 0)/(weights[x[:label]] || 1).to_f)*100).round(2); x[:loss_raw] = user_session_exit_counts[x[:label]].to_i; x[:color] = color_from_loss(x[:loss]);x}
#  edges = raw_edges.select{|e| node_names.include?(e["_id"]["rule_source"]) && node_names.include?(e["_id"]["rule_target"])}.collect{|te| {id: [node_names.index(te["_id"]["rule_source"]), node_names.index(te["_id"]["rule_target"])].join("_"), source: node_names.index(te["_id"]["rule_source"]), target: node_names.index(te["_id"]["rule_target"]), count: te["count"]}}
#  final_edges = edges.shuffle.first(final_nodes.count*2)
#  degrees = final_edges.collect{|x| [x[:source], x[:target]]}.flatten.uniq
#  {
#    nodes: final_nodes.select{|x| degrees.include?(x[:id])},
#    edges: final_edges,
#    exit_counts: user_session_exit_counts
#  }.to_json
#end
#
#post "/interactions/log.json" do
#  ProcessInteraction.perform_async(params[:interaction])
#end
#
#get "/visualizations/latest" do
#  params[:bot_id] = Bot.first.id.to_s
#  erb :"visualization"
#end
#
#get "/visualizations/latest/:bot_id" do
#  erb :"visualization"
#end
#
#get "/nodes/latest/:bot_id.json" do
#  content_type :json
#  Rule.where(bot_id: BSON::ObjectId(params["bot_id"])).to_a.collect{|r| {name: r.name}}.to_json
#end
#
#get "/rules/tooltip/:rule_id.json" do
#  rt = RuleTooltip.first(rule_id: BSON::ObjectId(params[:rule_id]))
#  dropped = Hash[rt.dropped_typical_bot_responses.collect{|k,v| [k,v.to_f/rt.dropped_user_count]}]
#  not_dropped = Hash[rt.not_dropped_typical_bot_responses.collect{|k,v| [k,v.to_f/rt.not_dropped_user_count]}]
#  should_change = dropped.collect{|k,v| [k,v-not_dropped[k]] if not_dropped[k]}.compact.sort_by{|k,v| v}.reverse
#  rule = Rule.find(BSON::ObjectId(params[:rule_id]))
#  total_exits = Interaction.where(account_id: rule.account_id, bot_id: rule.bot_id, platform: rule.platform, bot_rule: rule.name).count.to_f
#  total_count = TemporalEdge.where(account_id: rule.account_id, bot_id: rule.bot_id, platform: rule.platform, rule_source: rule.name).count.to_f
#  next_steps = Hash[TemporalEdge.collection.aggregate([{"$match" => {account_id: rule.account_id, bot_id: rule.bot_id, platform: rule.platform, rule_source: rule.name}}, {"$group" => {"_id" => {"rule_target" => "$rule_target"}, "count" => {"$sum" => 1}}}]).collect{|x| [x["_id"]["rule_target"], x["count"]/total_count > 1 ? 1.00 : x["count"]/total_count]}.sort_by{|k,v| v}.reverse]
#  rule_id_map = Hash[Rule.where(account_id: rule.account_id, bot_id: rule.bot_id, platform: rule.platform).fields(:_id, :name).collect{|r| [r.name, r.id]}]
#  inverted_rule_id_map = rule_id_map.invert
#  dropped_interaction_risks = Hash[RuleTooltip.where(rule_id: next_steps.collect{|k,v| rule_id_map[k]}).collect{|rt_t| [inverted_rule_id_map[rt_t.rule_id], rt_t.dropped_interaction_count.to_f/(rt_t.not_dropped_interaction_count.to_f+rt_t.dropped_interaction_count.to_f)]}.sort_by{|k,v| v}.reverse]
#  JSON.parse(rt.to_json).merge(should_change: should_change, next_steps: next_steps.to_a, dropped_interaction_risks: next_steps.collect{|k,v| [k, dropped_interaction_risks[k]]}).to_json
#end
