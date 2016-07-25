class UserBlacklist
  include MongoMapper::Document
  key :bot_id, BSON::ObjectId
  key :platform, String
  key :blacklist, Array
  
  def self.add_user(bot_id, platform, user_id)
    ub = UserBlacklist.first_or_create(bot_id: bot_id, platform: platform)
    ub.blacklist = ub.blacklist|[user_id].flatten
    ub.save!
  end

  def self.drop_user(bot_id, platform, user_id)
    ub = UserBlacklist.first_or_create(bot_id: bot_id, platform: platform)
    ub.blacklist = ub.blacklist-[user_id].flatten
    ub.save!
  end
end

#ub = UserBlacklist.new
#ub.bot_id = Bot.first.id
#Bot.count
#ub.platform = "facebook"
#ub.blacklist = ["facebook-dXNlcjpBZAVJmYTFwMUtJQnNkQ2NFMV8zcWtqaUpXanBxS0VVZAHJXdmppMTNBM0duQjhyRDJrNEVUaUJiWEZAHWXVVemotUDlqR0U3cE92djR5azlJN19SX0F3ODNuOXE3SjNYSnRZAVlJkblpZAV0JMWGVKdwZDZD",
#"facebook-dXNlcjpBZAVNoaTdfdjlaUXYxQmFfRHRaMTBhWG5PRlJhbVdJLWEzMzFoN2hHTkVhLVREaU9zWmJJQW1pQzF3SVN6R053b2R5djdUalRTT0FoVm5JRVA4LU1VSEhJUlhBdlk3bndHNjJpNDh3RW42Q0sxZAwZDZD",
#"facebook-dXNlcjpBZAVFqLXUyX0RwRGxZAYnN5NWM1MTVqRWNwVzIzWTE1cE8xQ21CcmVhUUkwVUZAxTzdTa2stN3lNaG5TR1JVdVdUSjJ3Y0ZA3WVdSR0pmZAHNmLWRBZAVpuSTZABUHhTOFlWaDQ1SVY1WUlXdzd1MHNGUQZDZD",
#"facebook-dXNlcjpBZAVRmWkJ1dlg5VzZA6T01ZAM1ZABTnZAxWmxDZAkdGaFM1RTFSN3FtRlJVR1dacXBmMFVRMTlTNi01Sy1tMWNZAclpoTzVrUWJNcnpBcXc4aXY3bXpUelFwNjFLT3N4WGMtbkhubExjbjV5VFMxUVVudwZDZD",
#"facebook-dXNlcjpBZAVJFblpJU1FqZADU3SzFjaWdmbGhJdngwUGNOU3JPZAlJHQ3lFMlFCT3JYcGpwWHMwd3NHbU95VUpuYWlvNWotMUNiempXQlBNV2xzdU9GZATJzZAXBpZAk5IRWtiVUdyMmtBNjJqeDB2MVlqQWtkdwZDZD",
#"facebook-dXNlcjpBZAVRlUmQ1c0VXYmFFWF9QT3RnSGxrQmpLTklPYmtnVHJ5NkdzZA3ZADdmVGSC1Eem5JX3cxTjNVb2RZAT2ZAHOHBCWUQwWC1jMHZAjcFlOWTl1ZAmdjSFFybTJfRHpyb081RVh4UnFwZAHd2T29XWmRmdwZDZD"]
#ub.save!