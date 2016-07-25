class Bot
  include MongoMapper::Document
  key :account_id, BSON::ObjectId
  key :bot_name, String
  key :platforms_supported, Array
  timestamps!
end