class RiveManifestUpdate
  include MongoMapper::Document
  key :account_id, BSON::ObjectId
  key :bot_id, BSON::ObjectId
  key :platform, String
  key :manifest_old, Hash
  key :manifest_new, Hash
  timestamps!
end