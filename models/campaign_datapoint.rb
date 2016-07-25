class CampaignDatapoint
  include MongoMapper::Document
  key :bot_id, BSON::ObjectId
  key :rule_id, BSON::ObjectId
  key :start_time, Time
  key :end_time, Time
  key :content, Hash
  timestamps!
end