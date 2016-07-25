class Account
  include MongoMapper::Document
  key :account_name, String
  key :bot_ids, Array
  key :account_user_ids, Array
  key :admin_ids, Array
  timestamps!
  
  def users
    AccountUser.where(id: self.account_user_ids)
  end

  def self.account_onboard(account_name, bot_name, platforms_supported)
    account = nil
    if Account.first(account_name: account_name).nil?
      Account.create(account_name: account_name)
      account = Account.first(account_name: account_name)
      Bot.create(account_id: account.id, bot_name: bot_name, platforms_supported: platforms_supported)
      bot = Bot.first(account_id: account.id, bot_name: bot_name)
      account.bot_ids << bot.id
      account.save!
    else
      return {error: "Account already existing, choose new name"}
    end
    {success: account}
  end

  def self.add_bot(account_id, bot_name, platforms)
    account = Account.find(account_id)
    Bot.create(account_id: account.id, bot_name: bot_name, platforms_supported: platforms)
    bot = Bot.first(account_id: account.id, bot_name: bot_name)
    account.bot_ids << bot.id
    account.save!
  end
  
  def self.drop_bot(account_id, bot_id)
    account = Account.find(account_id)
    bot = Bot.find(bot_id)
    bot.destroy
    account.bot_ids << bot.id
    account.save!
  end
  
  def self.add_platform(bot_id, platform)
    platforms = [platform].flatten
    bot = Bot.find(bot_id)
    bot.platforms_supported = bot.platforms_supported|platforms
    bot.save!
  end

  def self.drop_platform(bot_id, platform)
    platforms = [platform].flatten
    bot = Bot.find(bot_id)
    bot.platforms_supported = bot.platforms_supported-platforms
    bot.save!
  end
  
  def remove_account_user(account_user_id)
    self.account_user_ids -= [BSON::ObjectId(account_user_id.to_s)]
    self.admin_ids -= [BSON::ObjectId(account_user_id.to_s)]
    account_user = AccountUser.find(BSON::ObjectId(account_user_id.to_s))
    account_user.account_ids -= [self.id]
    self.save!
    account_user.save!
  end
end
#Account.account_onboard("poncho", "poncho_app", ["facebook"])