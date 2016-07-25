class Edge
  include MongoMapper::Document
  key :rule_source, String
  key :rule_target, String
  key :bot_id, BSON::ObjectId
  key :platform, String
  key :account_id, BSON::ObjectId
  key :transit_count, Integer
  key :exit_count, Integer
  key :started_at, Time
  key :ended_at, Time
  timestamps!
end