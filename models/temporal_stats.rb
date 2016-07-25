class TemporalStats
  include MongoMapper::Document
  key :bot_id, BSON::ObjectId
  key :content, Hash
  key :started_at, Time
  key :ended_at, Time
end

#t = (Time.now-90.days)
#time_cursor = Time.parse(t.strftime("%Y-%m-%d 00:00:00"))
#while time_cursor < Time.now
#  ts = TemporalStats.new(bot_id: BSON::ObjectId('5764354317a6e9faf1000002'))
#  ts.content = {}
#  user_sessions = UserSession.where(:first_rule_time.gte => time_cursor, :last_rule_time.lt => time_cursor+24*60*60, bot_id: BSON::ObjectId(params[:bot_id])).first.to_a
#  ts.content[:avg_message_length] = user_sessions.collect(&:interactions).collect(&:length).average
#  ts.content[:avg_message_length] = 0 if user_sessions.length == 0
#  ts.content[:avg_message_duration] = user_sessions.collect{|x| (x.last_time_hit-x.first_time_hit)/60/60.0}.average
#  ts.content[:avg_message_duration] = 0 if user_sessions.length == 0
#  ts.started_at = time_cursor
#  ts.ended_at = time_cursor+24*60*60
#  ts.save!
#  time_cursor += 24*60*60
#end
