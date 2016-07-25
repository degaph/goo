class TemporalEdge
include MongoMapper::Document
  key :rule_source, String
  key :rule_target, String
  key :rule_source_session, String
  key :rule_target_session, String
  key :interevent_time, Float
  key :bot_id, BSON::ObjectId
  key :platform, String
  key :account_id, BSON::ObjectId
  key :occurred_at, Time
  key :lifetime_count, Integer
  key :user_id, String
  timestamps!
end