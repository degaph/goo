class Node
  include MongoMapper::Document
  key :label
  key :bot_id
  key :platform
  key :account_id
  timestamps!
end