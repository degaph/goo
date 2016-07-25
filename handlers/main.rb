def set_params
  redirect "/" if session[:account_id].nil?
  @bot ||= params[:bot_id] ? Bot.find(params[:bot_id]) : Bot.find(Account.find(session[:account_id]).bot_ids.first)
  @percentile_low = (params[:percentile_low] && params[:percentile_low].to_i) || 0
  @percentile_high = (params[:percentile_high] && params[:percentile_high].to_i) || 100
  @per_page = (params[:per_page] && params[:per_page].to_i) || 20
  @page = (params[:page] && params[:page].to_i) || 1
  if params[:start_time] && params[:end_time]
    @start_time = Time.parse(params[:start_time].split(" to ").first+" 00:00:00")
    @end_time = Time.parse(params[:end_time].split(" to ").last+" 23:59:59")  
  elsif params[:timeframe]
    @start_time = Time.parse(params[:timeframe].split(" to ").first+" 00:00:00")
    @end_time = Time.parse(params[:timeframe].split(" to ").last+" 23:59:59")  
  else
    @start_time = Time.parse((Time.now-30.days).strftime("%Y-%m-%d 00:00:00"))
    @end_time = Time.parse(Time.now.strftime("%Y-%m-%d 23:59:59"))
  end
  @default_timeframe_string = @start_time.strftime("%Y-%m-%d")+" to "+@end_time.strftime("%Y-%m-%d")
  @platforms = params.keys.collect(&:to_s)-["rule_id", "bot_id", "percentile_low", "percentile_high", "per_page", "start_time", "end_time", "splat", "captures"]
  @platforms = @bot.platforms_supported if @platforms.empty?
  interaction_counts = Interaction.where(:time.gte => @start_time, :time.lte => @end_time, bot_id: @bot.id, platform: @platforms).distinct(:lifetime_count).sort
  @interaction_count_low = interaction_counts.percentile(@percentile_low/100.0)
  @interaction_count_high = interaction_counts.percentile(@percentile_high/100.0)
end

def generate_retention_grid_data(match_query)
  mapped_cohort_data = {}
  generalized_cohort_data = {}
  cohort_raw_data = UserSession.collection.aggregate([
    {"$match" => match_query}, 
    {"$group" => {"_id" => {"user_id" => "$user_id", "cohort_day" => {"$dayOfMonth" => "$first_user_time"}, "cohort_month" => {"$month" => "$first_user_time"}, "cohort_year" => {"$year" => "$first_user_time"}, "day" => {"$dayOfMonth" => "$last_rule_time"}, "month" => {"$month" => "$last_rule_time"}, "year" => {"$year" => "$last_rule_time"}}}}])
  cohort_raw_data.each do |row|
    cohort_time = Time.parse(row["_id"]["cohort_year"].to_s+"-"+row["_id"]["cohort_month"].to_s+"-"+row["_id"]["cohort_day"].to_s+" 00:00:00")
    session_time = Time.parse(row["_id"]["year"].to_s+"-"+row["_id"]["month"].to_s+"-"+row["_id"]["day"].to_s+" 00:00:00")
    generalized_cohort_data[((session_time-cohort_time)/(24*60*60)).to_i] ||= []
    generalized_cohort_data[((session_time-cohort_time)/(24*60*60)).to_i] << row["_id"]["user_id"]
    mapped_cohort_data[cohort_time] ||= {}
    mapped_cohort_data[cohort_time][session_time] ||= []
    mapped_cohort_data[cohort_time][session_time] << row["_id"]["user_id"]
  end
  dataset = []
  sorted_keys = mapped_cohort_data.keys.sort
  return [[], [], []] if mapped_cohort_data.empty?
  first_time = sorted_keys.first
  last_time = sorted_keys.last
  cursor = first_time
  numbers = []
  while cursor < last_time
    if mapped_cohort_data[cursor] && mapped_cohort_data[cursor][cursor]
      acquisitions = mapped_cohort_data[cursor][cursor].uniq.length
      returns = [Time.parse(cursor.to_s), acquisitions]
      inner_cursor = cursor+24*60*60
      while inner_cursor <= last_time
        if mapped_cohort_data[cursor][inner_cursor]
          number = mapped_cohort_data[cursor][inner_cursor].uniq.length.to_f/returns[1]
          returns << number
          numbers << number
        else
          number = 0/returns[1]
          returns << number
          numbers << number
        end
        inner_cursor +=  24*60*60
      end
      dataset << returns
    else
      returns = [Time.parse(cursor.to_s), 0]
      ((last_time-cursor).to_i/(24*60*60)).times{|x| returns << 0}
      dataset << returns    
    end
    cursor += 24*60*60
  end
  general_retention = []
  generalized_cohort_data.keys.sort.each do |key|
    general_retention << generalized_cohort_data[key].uniq.length.to_f/generalized_cohort_data[0].uniq.length.to_f
  end
  [dataset, numbers.sort, general_retention]
end

def color_from_loss(loss)
  if loss/100 < 0.01
    "rgb(44,110,24)"
  elsif loss/100 < 0.10
    "rgb(199,145,38)"
  else
    "rgb(110,17,0)"
  end
end

use Rack::Auth::Basic, "Restricted Area" do |username, password|
  username == 'gooble' and password == 'gobble'
end

get "/" do
  @warning = nil
  if session[:account_name].nil?
    erb :"login"
  else
    erb :"landing"
  end
end


post "/network/latest/:bot_id.json" do
  
end
get "/visualization/:bot_id.json" do
erb :"visualization"
end

get "/rules/:rule_id/:start_time/:end_time/examples.json" do
  set_params
  puts params.inspect
  @rule = Rule.first(id: params[:rule_id])
  @rule.get_good_examples(@interaction_count_low, @interaction_count_high, @start_time, @end_time).to_json
end

get "/rules/:rule_id/:start_time/:end_time/timeline_data.json" do
  set_params
  puts params.inspect
  @rule = Rule.first(id: params[:rule_id])
  @interactions_timeline = Hash[CollectionHelper.match_and_group(Interaction, {"lifetime_count" => {"$gte" => @interaction_count_low, "$lte" => @interaction_count_high}, "time" => {"$gte" => @start_time, "$lte" => @end_time}, "bot_rule" => @rule.name, "platform" => @rule.platform}, {"_id" => {"day" => {"$dayOfMonth" => "$time"}, "month" => {"$month" => "$time"}, "year" => {"$year" => "$time"}}, "count" => {"$sum" => 1}}).collect{|x| [Time.parse(x["_id"]["year"].to_s+"-"+x["_id"]["month"].to_s+"-"+x["_id"]["day"].to_s+" 00:00:00"), x["count"]]}]
  @session_drops_timeline = Hash[CollectionHelper.match_and_group(UserSession, {"lifetime_count" => {"$gte" => @interaction_count_low, "$lte" => @interaction_count_high}, "last_rule_time" => {"$gte" => @start_time, "$lte" => @end_time}, "last_rule_hit" => @rule.name, "platform" => @rule.platform}, {"_id" => {"day" => {"$dayOfMonth" => "$last_rule_time"}, "month" => {"$month" => "$last_rule_time"}, "year" => {"$year" => "$last_rule_time"}}, "count" => {"$sum" => 1}}).collect{|x| [Time.parse(x["_id"]["year"].to_s+"-"+x["_id"]["month"].to_s+"-"+x["_id"]["day"].to_s+" 00:00:00"), x["count"]]}]  
  @merged_timeline = CollectionHelper.merge_timelines({"Bounces" => @session_drops_timeline, "Interactions" => @interactions_timeline})
  @merged_timeline.to_json
end

get "/rules/:rule_id/:start_time/:end_time/timeline_data_all_platforms.json" do
  set_params
  puts params.inspect
  @rule = Rule.first(id: params[:rule_id])
  @interactions_timeline_all_platforms = Hash[CollectionHelper.match_and_group(Interaction, {"lifetime_count" => {"$gte" => @interaction_count_low, "$lte" => @interaction_count_high}, "time" => {"$gte" => @start_time, "$lte" => @end_time}, "bot_rule" => @rule.name}, {"_id" => {"day" => {"$dayOfMonth" => "$time"}, "month" => {"$month" => "$time"}, "year" => {"$year" => "$time"}}, "count" => {"$sum" => 1}}).collect{|x| [Time.parse(x["_id"]["year"].to_s+"-"+x["_id"]["month"].to_s+"-"+x["_id"]["day"].to_s+" 00:00:00"), x["count"]]}]
  @session_drops_timeline_all_platforms = Hash[CollectionHelper.match_and_group(UserSession, {"lifetime_count" => {"$gte" => @interaction_count_low, "$lte" => @interaction_count_high}, "last_rule_time" => {"$gte" => @start_time, "$lte" => @end_time}, "last_rule_hit" => @rule.name}, {"_id" => {"day" => {"$dayOfMonth" => "$last_rule_time"}, "month" => {"$month" => "$last_rule_time"}, "year" => {"$year" => "$last_rule_time"}}, "count" => {"$sum" => 1}}).collect{|x| [Time.parse(x["_id"]["year"].to_s+"-"+x["_id"]["month"].to_s+"-"+x["_id"]["day"].to_s+" 00:00:00"), x["count"]]}]  
  @merged_timeline = CollectionHelper.merge_timelines({"Bounces" => @session_drops_timeline_all_platforms, "Interactions" => @interactions_timeline_all_platforms})
  @merged_timeline.to_json
end

get "/rules/outline/:bot_id/:start_time/:end_time/return_trips.json" do
  set_params
  @edges = Hash[CollectionHelper.match_and_group(TemporalEdge, {"interevent_time" => {"$gt" => 15*60}, "bot_id" => @bot.id, "platform" => {"$in" => @platforms}, "lifetime_count" => {"$gte" => @interaction_count_low, "$lte" => @interaction_count_high}, "occurred_at" => {"$gte" => @start_time, "$lte" => @end_time}}, {"_id" => "$rule_target", "count" => {"$sum" => 1}}).collect{|x| [x["_id"], x["count"]]}.sort_by{|k,v| v}.reverse];false
  @rules = Hash[Rule.where(bot_id: @bot.id, platform: @platforms, name: @edges.keys).collect{|x| [x.name, {topic: x.topic, platform: x.platform, id: x.id}]}]
  @last_rule_hits = Hash[CollectionHelper.match_and_group(UserSession, {"bot_id" => @bot.id, "platform" => {"$in" => @platforms}, "last_rule_hit" => {"$in" => @edges.keys}, "lifetime_count" => {"$gte" => @interaction_count_low, "$lte" => @interaction_count_high}, "last_rule_time" => {"$gte" => @start_time, "$lte" => @end_time}}, {"_id" => {"last_rule_hit" => "$last_rule_hit"}, "count" => {"$sum" => 1}}).collect{|x| [x["_id"]["last_rule_hit"], x["count"]]}.sort_by{|k,v| v}.reverse];false
  @counts = Hash[CollectionHelper.match_and_group(Interaction, {"bot_id" => @bot.id, "platform" => {"$in" => @platforms}, "bot_rule" => {"$in" => @edges.keys}, "lifetime_count" => {"$gte" => @interaction_count_low, "$lte" => @interaction_count_high}, "time" => {"$gte" => @start_time, "$lte" => @end_time}}, {"_id" => {"bot_rule" => "$bot_rule"}, "count" => {"$sum" => 1}}).collect{|k| [k["_id"]["bot_rule"], k["count"]]}.sort_by{|k,v| v}.reverse];false
  @risks = Hash[@edges.keys.collect{|k| [k, @last_rule_hits[k].to_i/@counts[k].to_f]}];false
  @edges.collect{|k,v| {rule_name: k.length > 100 ? k[0..80]+"..." : k, return_frequency: v, risk: @risks[k].to_f}.merge(@rules[k])}.to_json
end

get "/rules/outline/:bot_id/:start_time/:end_time/timeline_data.json" do
  set_params
  @interactions_timeline = Hash[CollectionHelper.match_and_group(Interaction, {"bot_id" => @bot.id, "platform" => {"$in" => @platforms}, "lifetime_count" => {"$gte" => @interaction_count_low, "$lte" => @interaction_count_high}, "time" => {"$gte" => @start_time, "$lte" => @end_time}}, {"_id" => {"day" => {"$dayOfMonth" => "$time"}, "month" => {"$month" => "$time"}, "year" => {"$year" => "$time"}}, "count" => {"$sum" => 1}}).collect{|x| [Time.parse(x["_id"]["year"].to_s+"-"+x["_id"]["month"].to_s+"-"+x["_id"]["day"].to_s+" 00:00:00"), x["count"]]}]
  @session_drops_timeline = Hash[CollectionHelper.match_and_group(UserSession, {"bot_id" => @bot.id, "platform" => {"$in" => @platforms}, "lifetime_count" => {"$gte" => @interaction_count_low, "$lte" => @interaction_count_high}, "last_rule_time" => {"$gte" => @start_time, "$lte" => @end_time}}, {"_id" => {"day" => {"$dayOfMonth" => "$last_rule_time"}, "month" => {"$month" => "$last_rule_time"}, "year" => {"$year" => "$last_rule_time"}}, "count" => {"$sum" => 1}}).collect{|x| [Time.parse(x["_id"]["year"].to_s+"-"+x["_id"]["month"].to_s+"-"+x["_id"]["day"].to_s+" 00:00:00"), x["count"]]}]
  @user_acquisitions = Hash[CollectionHelper.match_and_group(User, {"bot_id" => @bot.id, "platform" => {"$in" => @platforms}, "lifetime_count" => {"$gte" => @interaction_count_low, "$lte" => @interaction_count_high}, "first_rule_time" => {"$gte" => @start_time, "$lte" => @end_time}}, {"_id" => {"day" => {"$dayOfMonth" => "$first_rule_time"}, "month" => {"$month" => "$first_rule_time"}, "year" => {"$year" => "$first_rule_time"}}, "count" => {"$sum" => 1}}).collect{|x| [Time.parse(x["_id"]["year"].to_s+"-"+x["_id"]["month"].to_s+"-"+x["_id"]["day"].to_s+" 00:00:00"), x["count"]]}]
  @merged_timeline = CollectionHelper.merge_timelines({"New Users" => @user_acquisitions, "Sessions" => @session_drops_timeline, "Interactions" => @interactions_timeline})
  @merged_timeline.to_json
end

get "/rules/outline/:bot_id/:start_time/:end_time/count_data.json" do
  set_params
  @user_session_count = UserSession.count("bot_id" => @bot.id, "platform" => @platforms, :lifetime_count.gte => @interaction_count_low, :lifetime_count.lte => @interaction_count_high, :last_rule_time.gte => @start_time, :last_rule_time.lte => @end_time)
  @user_count = User.count("bot_id" => @bot.id, "platform" => @platforms, :lifetime_count.gte => @interaction_count_low, :lifetime_count.lte => @interaction_count_high, :last_rule_time.gte => @start_time, :last_rule_time.lte => @end_time)
  @user_session_length_average = UserSession.collection.aggregate([{"$match" => {"bot_id" => @bot.id, "platform" => {"$in" => @platforms}, "lifetime_count" => {"$gte" => @interaction_count_low, "$lte" => @interaction_count_high}, "last_rule_time" => {"$gte" => @start_time, "$lte" => @end_time}}}, {"$project" => {"_id" => "$id", "time_dist" => {"$subtract" => ["$last_rule_time", "$first_rule_time"]}}}]).collect{|x| x["time_dist"]/1000}.reject{|x| x < 0}.average
  @user_session_count_messages = User.collection.aggregate([{"$match" => {"bot_id" => @bot.id, "platform" => {"$in" => @platforms}, "lifetime_count" => {"$gte" => @interaction_count_low, "$lte" => @interaction_count_high}, "last_rule_time" => {"$gte" => @start_time, "$lte" => @end_time}}}, {"$project" => {"_id" => "$id", "size" => {"$size" => "$sessions"}}}]).collect{|x| x["size"]}.average
  @rule_count = Rule.where(bot_id: @bot.id).count
  {sessions_per_user: @user_session_count/@user_count, user_session_count: @user_session_count.commas, user_count: @user_count.commas, user_session_length_average: @user_session_length_average.round(2), user_session_count_messages: @user_session_count_messages.round(2), rule_count: @rule_count.commas}.to_json
end

get "/rules/outline/:bot_id/:start_time/:end_time/retention_grid.json" do
  set_params
  @retention_grid = generate_retention_grid_data({"bot_id" => @bot.id, "platform" => {"$in" => @platforms}, "lifetime_count" => {"$gte" => @interaction_count_low, "$lte" => @interaction_count_high}, "first_user_time" => {"$gte" => @start_time, "$lte" => @end_time}})
  @retention_grid[0] = @retention_grid[0].collect{|x| x.collect{|y| y.class == Time ? y : [y,(@retention_grid[1].reverse_percentile(y)*9).to_i]}}
  {retention_grid: @retention_grid, general_retention: @retention_grid[2].collect{|x| [x, (@retention_grid[2].sort.reverse_percentile(x)*9).to_i]}.each_slice(10).to_a}.to_json
end

def get_outline
  @bot = Bot.first(id: params[:bot_id])
  @counts = Hash[CollectionHelper.match_and_group(Interaction, {"bot_id" => @bot.id, "platform" => {"$in" => @platforms}, "lifetime_count" => {"$gte" => @interaction_count_low, "$lte" => @interaction_count_high}, "time" => {"$gte" => @start_time, "$lte" => @end_time}}, {"_id" => {"bot_rule" => "$bot_rule", "platform" => "$platform"}, "count" => {"$sum" => 1}}).collect{|k| [[k["_id"]["bot_rule"], k["_id"]["platform"]], k["count"]]}.sort_by{|k,v| v}.reverse]
  @last_rule_hits = Hash[CollectionHelper.match_and_group(UserSession, {"bot_id" => @bot.id, "platform" => {"$in" => @platforms}, "lifetime_count" => {"$gte" => @interaction_count_low, "$lte" => @interaction_count_high}, "last_rule_time" => {"$gte" => @start_time, "$lte" => @end_time}}, {"_id" => {"last_rule_hit" => "$last_rule_hit", "platform" => "$platform"}, "count" => {"$sum" => 1}}).collect{|x| [[x["_id"]["last_rule_hit"], x["_id"]["platform"]], x["count"]]}.sort_by{|k,v| v}.reverse]
  @rules = @counts.collect(&:first).collect{|r| Rule.where(name: r[0], platform: r[1]).first}
  erb :"rule_index"
end

def drops_and_interactions
  @session_drops = UserSession.where(platform: @rule.platform, :lifetime_count.gte => @interaction_count_low, :lifetime_count.lte => @interaction_count_high, :last_rule_time.gte => @start_time, :last_rule_time.lte => @end_time, last_rule_hit: @rule.name).count
  @interactions = Interaction.where(platform: @rule.platform, :lifetime_count.gte => @interaction_count_low, :lifetime_count.lte => @interaction_count_high, :time.gte => @start_time, :time.lte => @end_time, bot_rule: @rule.name).count
  @session_drops_all_platforms = UserSession.where(:lifetime_count.gte => @interaction_count_low, :lifetime_count.lte => @interaction_count_high, :last_rule_time.gte => @start_time, :last_rule_time.lte => @end_time, last_rule_hit: @rule.name).count
  @interactions_all_platforms = Interaction.where(:lifetime_count.gte => @interaction_count_low, :lifetime_count.lte => @interaction_count_high, :time.gte => @start_time, :time.lte => @end_time, bot_rule: @rule.name).count
end

def next_steps
  @total_count = TemporalEdge.where(:lifetime_count.gte => @interaction_count_low, :lifetime_count.lte => @interaction_count_high, :occurred_at.gte => @start_time, :occurred_at.lte => @end_time, account_id: @rule.account_id, bot_id: @rule.bot_id, platform: @rule.platform, rule_source: @rule.name).count.to_f
  @total_count_all_platforms = TemporalEdge.where(:lifetime_count.gte => @interaction_count_low, :lifetime_count.lte => @interaction_count_high, :occurred_at.gte => @start_time, :occurred_at.lte => @end_time, account_id: @rule.account_id, bot_id: @rule.bot_id, rule_source: @rule.name).count.to_f
  @next_step = Hash[TemporalEdge.collection.aggregate([{"$match" => {"lifetime_count" => {"$gte" => @interaction_count_low, "$lte" => @interaction_count_high}, "occurred_at" => {"$gte" => @start_time, "$lte" => @end_time}, account_id: @rule.account_id, bot_id: @rule.bot_id, platform: @rule.platform, rule_source: @rule.name}}, {"$group" => {"_id" => {"rule_target" => "$rule_target"}, "count" => {"$sum" => 1}}}]).collect{|x| [x["_id"]["rule_target"], x["count"]/@total_count > 1 ? 1.00 : x["count"]/@total_count]}.sort_by{|k,v| v}.reverse]
  @next_step_all_platforms = Hash[TemporalEdge.collection.aggregate([{"$match" => {"lifetime_count" => {"$gte" => @interaction_count_low, "$lte" => @interaction_count_high}, "occurred_at" => {"$gte" => @start_time, "$lte" => @end_time}, account_id: @rule.account_id, bot_id: @rule.bot_id, rule_source: @rule.name}}, {"$group" => {"_id" => {"rule_target" => "$rule_target"}, "count" => {"$sum" => 1}}}]).collect{|x| [x["_id"]["rule_target"], x["count"]/@total_count_all_platforms > 1 ? 1.00 : x["count"]/@total_count_all_platforms]}.sort_by{|k,v| v}.reverse]
  @rule_id_map = Hash[Rule.where(account_id: @rule.account_id, bot_id: @rule.bot_id, platform: @rule.platform).fields(:_id, :name).collect{|r| [r.name, r.id] if @next_step.keys.include?(r.name)}.compact]
  temp = Rule.where(account_id: @rule.account_id, bot_id: @rule.bot_id).fields(:_id, :name).collect{|r| [r.name, r.id] if @next_step_all_platforms.keys.include?(r.name)}.compact
  @rule_id_map_all_platforms = {}
  temp.collect{|k,v| @rule_id_map_all_platforms[k]||= []; @rule_id_map_all_platforms[k] << v}
  @rules = Hash[Rule.where(id: @rule_id_map.values).to_a.collect{|x| [x.id, x]}]
  @rules_all_platforms = Hash[Rule.where(id: @rule_id_map.values.flatten).to_a.collect{|x| [x.id, x]}]
  next_dropped_interaction_counts = Hash[UserSession.collection.aggregate([{"$match" => {"bot_id" => @rule.bot_id, "platform" => @rule.platform, "last_rule_hit" => {"$in" => @next_step.keys}, "last_rule_time" => {"$gte" => @start_time, "$lte" => @end_time}, "lifetime_count" => {"$gte" => @interaction_count_low, "$lte" => @interaction_count_high}}}, {"$group" => {"_id" => "$last_rule_hit", "count" => {"$sum" => 1}}}]).collect{|x| [x["_id"], x["count"]]}];false
  next_dropped_interaction_counts_all_platforms = Hash[UserSession.collection.aggregate([{"$match" => {"bot_id" => @rule.bot_id, "last_rule_hit" => {"$in" => @next_step_all_platforms.keys}, "last_rule_time" => {"$gte" => @start_time, "$lte" => @end_time}, "lifetime_count" => {"$gte" => @interaction_count_low, "$lte" => @interaction_count_high}}}, {"$group" => {"_id" => "$last_rule_hit", "count" => {"$sum" => 1}}}]).collect{|x| [x["_id"], x["count"]]}];false
  next_interaction_counts = Hash[Interaction.collection.aggregate([{"$match" => {"bot_id" => @rule.bot_id, "platform" => @rule.platform, "bot_rule" => {"$in" => @next_step.keys}, "time" => {"$gte" => @start_time, "$lte" => @end_time}, "lifetime_count" => {"$gte" => @interaction_count_low, "$lte" => @interaction_count_high}}}, {"$group" => {"_id" => "$bot_rule", "count" => {"$sum" => 1}}}]).collect{|x| [x["_id"], x["count"]]}];false
  next_interaction_counts_all_platforms = Hash[Interaction.collection.aggregate([{"$match" => {"bot_id" => @rule.bot_id, "bot_rule" => {"$in" => @next_step_all_platforms.keys}, "time" => {"$gte" => @start_time, "$lte" => @end_time}, "lifetime_count" => {"$gte" => @interaction_count_low, "$lte" => @interaction_count_high}}}, {"$group" => {"_id" => "$bot_rule", "count" => {"$sum" => 1}}}]).collect{|x| [x["_id"], x["count"]]}];false
  @next_risks = Hash[@rule_id_map.keys.collect{|rule| [rule, (next_dropped_interaction_counts[rule]||0)/((next_dropped_interaction_counts[rule]||0)+(next_interaction_counts[rule]||0)).to_f]}]
  @next_risks_all_platforms = Hash[@rule_id_map.keys.collect{|rule| [rule, (next_dropped_interaction_counts_all_platforms[rule]||0)/((next_dropped_interaction_counts_all_platforms[rule]||0)+(next_interaction_counts_all_platforms[rule]||0)).to_f]}]
  @next_risks.keys.collect{|k| @next_risks[k] = 0 if @next_risks[k].nan?}
  @next_risks_all_platforms.keys.collect{|k| @next_risks_all_platforms[k] = 0 if @next_risks_all_platforms[k].nan?}
end

def get_deep_dive
  @rule = Rule.first(id: params[:rule_id])
  @examples = @rule.get_good_examples(@interaction_count_low, @interaction_count_high, @start_time, @end_time)
  @bot = Bot.first(id: @rule.bot_id)
  @platforms = [@rule.platform]
  drops_and_interactions
  next_steps
  @rule_tooltip = RuleTooltip.generate_dynamic(BSON::ObjectId(params[:rule_id]), @start_time, @end_time, @interaction_count_low, @interaction_count_high)
  @dropped_raw = Hash[@rule_tooltip.dropped_typical_bot_responses.collect{|k,v| [k,v.to_f]}.reject{|k,v| v == 1}]
  @not_dropped_raw = Hash[@rule_tooltip.not_dropped_typical_bot_responses.collect{|k,v| [k,v.to_f]}.reject{|k,v| v == 1}]
  @significances = {}
  @dropped_raw.keys.each do |key|
    values = {
      key => {dropped: (@dropped_raw[key]||0), not_dropped: (@not_dropped_raw[key]||0)}, 
      "rest" => {dropped: @dropped_raw.values.sum-(@dropped_raw[key]||0), not_dropped: @not_dropped_raw.values.sum-(@not_dropped_raw[key]||0)}}
    chi_sq = ABAnalyzer::ABTest.new(values).chisquare_p rescue 1
    @significances[key] = {chi_square: chi_sq, fishers: Rubystats::FishersExactTest.new.calculate((@dropped_raw[key]||0), (@not_dropped_raw[key]||0), @dropped_raw.values.sum-(@dropped_raw[key]||0), @not_dropped_raw.values.sum-(@not_dropped_raw[key]||0))}
  end
  @should_change = @dropped_raw.collect{|k,v| [k,((v/(@not_dropped_raw[k]+v))*100).round(2), @not_dropped_raw[k]+v, ((v/(@not_dropped_raw[k]+v).to_f) > (@not_dropped_raw[k]/(@not_dropped_raw[k]+v).to_f) ? -1 : 1)] if @not_dropped_raw[k]}.compact.sort_by{|k,v| v}.sort_by{|sc| sc[2]}.reverse.first(10)
  erb :"deep_dive"
end

def set_body_params
  body_params = JSON.parse(request.body.read) rescue nil
  request.body.rewind
  body_params.each do |k,v| 
    params[k] = v
  end
  request.body.rewind
end

get "/rules/outline/:bot_id/:start_time/:end_time" do
  set_params
  redirect "/rules/outline/#{params[:bot_id]}?start_time=#{@start_time.strftime("%Y-%m-%d")}&end_time=#{@end_time.strftime("%Y-%m-%d")}&percentile_low=#{@percentile_low}&percentile_high=#{@percentile_high}#{@platforms.collect{|p| "&#{p}=#{p}"}.join("")}"
end

get "/rules/outline/:bot_id" do
  set_params
  puts params.inspect
  get_outline
end

post "/rules/outline/:bot_id" do
  set_params
  puts params.inspect
  redirect "/rules/outline/#{params[:bot_id]}?start_time=#{@start_time.strftime("%Y-%m-%d")}&end_time=#{@end_time.strftime("%Y-%m-%d")}&percentile_low=#{@percentile_low}&percentile_high=#{@percentile_high}#{@platforms.collect{|p| "&#{p}=#{p}"}.join("")}"
end

get "/rules/outline" do
  redirect "/rules/outline/#{Account.find(session[:account_id]).bot_ids.first}"
end

get "/rules/:rule_id/:start_time/:end_time" do
  set_params
  puts params.inspect
  get_deep_dive
end


get "/explanation" do
  erb :"explanation"
end
#thought: Companies can define their segments (i.e. start/end time frames, interaction count thresholds) and all this can be preprocessed back in rule tooltips.
#retention grid!
#people that come back, what rules do they hit when they come back
#Also show best-performing things on another tab maybe?
post "/rules/:rule_id/:start_time/:end_time" do
  set_params
  get_deep_dive
end

post "/apps/signup.json" do
  set_body_params
  puts params
  Account.account_onboard(params[:account_name], params[:bot_name], params[:platforms]).to_json
end

post "/apps/add_bot.json" do
  set_body_params
  puts params
  account = Account.first(account_name: params[:account_name])
  return {error: "Account not found!"}.to_json if account.nil?
  Account.add_bot(account.id, params[:bot_name], params[:platforms]).to_json
end

post "/apps/drop_bot.json" do
  set_body_params
  puts params
  account = Account.first(account_name: params[:account_name])
  return {error: "Account not found!"}.to_json if account.nil?
  bot = Bot.first(bot_name: params[:bot_name], account_id: account.id)
  return {error: "Bot not found!"}.to_json if bot.nil?
  Account.drop_bot(account.id, bot.id).to_json
end

post "/apps/add_platform.json" do
  set_body_params
  puts params
  account = Account.first(account_name: params[:account_name])
  return {error: "Account not found!"}.to_json if account.nil?
  bot = Bot.first(bot_name: params[:bot_name], account_id: account.id)
  return {error: "Bot not found!"}.to_json if bot.nil?
  Account.add_platform(bot.id, params[:platform]).to_json
end

post "/apps/drop_platform.json" do
  set_body_params
  puts params
  account = Account.first(account_name: params[:account_name])
  return {error: "Account not found!"}.to_json if account.nil?
  bot = Bot.first(bot_name: params[:bot_name], account_id: account.id)
  return {error: "Bot not found!"}.to_json if bot.nil?
  Account.drop_platform(bot.id, params[:platform]).to_json
end

post "/interactions/log.json" do
  set_body_params
  interaction_data = JSON.parse(request.body.read)
  required_params = [:account_name, :bot_name, :platform, :user_id, :bot_rule, :time, :user_input, :bot_response].collect(&:to_s)
  seen_params = interaction_data.keys.collect(&:to_s)
  return {error: "Not all required parameters are present! Parameters required are: #{required_params}. Params received were: #{seen_params}"}.to_json if required_params.sort != seen_params.sort
  puts params.inspect
  ProcessInteraction.perform_async(params).to_json
end

post "/user_blacklists/add_user.json" do
  set_body_params
  puts params
  account = Account.first(account_name: params[:account_name])
  return {error: "Account not found!"}.to_json if account.nil?
  bot = Bot.first(bot_name: params[:bot_name], account_id: account.id)
  return {error: "Bot not found!"}.to_json if bot.nil?
  UserBlacklist.add_user(bot.id, params[:platform], params[:user_id]).to_json
end

post "/user_blacklists/drop_user.json" do
  set_body_params
  puts params
  account = Account.first(account_name: params[:account_name])
  return {error: "Account not found!"}.to_json if account.nil?
  bot = Bot.first(bot_name: params[:bot_name], account_id: account.id)
  return {error: "Bot not found!"}.to_json if bot.nil?
  UserBlacklist.drop_user(bot.id, params[:platform], params[:user_id])
end

post "/manifests/ingest.json" do
  set_body_params
  puts params
  filename = params[:bot_name]+Time.now.to_i.to_s+".rive"
  File.open(filename, 'w') do |f|
    f.write params[:manifest_data]
  end
  account = Account.first(account_name: params[:account_name])
  return {error: "Account not found!"}.to_json if account.nil?
  bot = Bot.first(bot_name: params[:bot_name], account_id: account.id)
  return {error: "Bot not found!"}.to_json if bot.nil?
  RiveManifest.ingest(filename, bot.id, params[:platform])
end

get "/documentation" do
  erb :"documentation"
end
#@start_time = Time.now-200.days
#@end_time = Time.now
#@interaction_count_low = 0
#@interaction_count_high = 5
#rules = gz.reverse
#mapped_ab_tests = {}
#i = 0
#rules[49..-1].first(50).each do |rule|
#i+=1
#puts i
#  @rule_tooltip = RuleTooltip.generate_dynamic(rule.id, @start_time, @end_time, @interaction_count_low, @interaction_count_high)
#  @dropped_raw = Hash[@rule_tooltip.dropped_typical_bot_responses.collect{|k,v| [k,v.to_f]}.reject{|k,v| v == 1}]
#  @not_dropped_raw = Hash[@rule_tooltip.not_dropped_typical_bot_responses.collect{|k,v| [k,v.to_f]}.reject{|k,v| v == 1}]
#  @significances = {}
#  @dropped_raw.keys.each do |key|
#    values = {
#      key => {dropped: (@dropped_raw[key]||0), not_dropped: (@not_dropped_raw[key]||0)}, 
#      "rest" => {dropped: @dropped_raw.values.sum-(@dropped_raw[key]||0), not_dropped: @not_dropped_raw.values.sum-(@not_dropped_raw[key]||0)}}
#    chi_sq = ABAnalyzer::ABTest.new(values).chisquare_p rescue 1
#    @significances[key] = {chi_square: chi_sq, fishers: Rubystats::FishersExactTest.new.calculate((@dropped_raw[key]||0), (@not_dropped_raw[key]||0), @dropped_raw.values.sum-(@dropped_raw[key]||0), @not_dropped_raw.values.sum-(@not_dropped_raw[key]||0))}
#  end
#  @should_change = @dropped_raw.collect{|k,v| [k,((v/(@not_dropped_raw[k]+v))*100).round(2), @not_dropped_raw[k]+v, ((v/(@not_dropped_raw[k]+v).to_f) > (@not_dropped_raw[k]/(@not_dropped_raw[k]+v).to_f) ? -1 : 1)] if @not_dropped_raw[k]}.compact.sort_by{|k,v| v}.sort_by{|sc| sc[2]}.reverse.first(10)
#  mapped_ab_tests[rule.id] = {significances: @significances, should_changes: @should_change}
#end
#mapped_ab_tests.select{|k,v| v[:significances].collect{|kk,r| kk != "[[typing]]" && kk != " " && kk != "" && r[:chi_square] < 0.05}.include?(true) && v[:should_changes].collect{|sc| sc[3]}.include?(1) && v[:should_changes].collect{|sc| sc[3]}.include?(-1)}
# csv = CSV.open("zoom_ai_edges.csv", "w")
# csv << ["source", "target"]
# gz.uniq.count
# gz.counts.first
# gz.counts.collect{|k,v| csv << [k[0], k[1], v]};false
# csv.close
# inter_counts = {}
# exit_counts = {}
# UserSession.where(bot_id: bot_id).collect{|us| exit_counts[us.last_rule_hit] ||= 0; exit_counts[us.last_rule_hit] += 1; }
# Interaction.where(bot_id: bot_id).collect{|x| inter_counts[x.bot_rule] ||= 0 ; inter_counts[x.bot_rule] += 1};false
# csv = CSV.open("zoom_ai_nodes.csv", "w")
# csv << ["id", "interaction_count", "bounce_val"]
# inter_counts.collect{|k,v| csv << [k, v, exit_counts[k].to_f/v]}
# csv.close