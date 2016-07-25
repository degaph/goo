class RiveManifest
  include MongoMapper::Document
  key :account_id, BSON::ObjectId
  key :bot_id, BSON::ObjectId
  key :platform, String
  key :manifest, Hash
  timestamps!
  def self.ingest(file, bot_id, platform)
    bot = Bot.find(bot_id)
    previous_manifest = RiveManifest.order(:created_at.desc).first(account_id: bot.account_id, bot_id: bot_id, platform: platform)
    new_manifest = nil
    if previous_manifest
      new_manifest = RiveManifest.new(account_id: bot.account_id, bot_id: bot_id, platform: platform, manifest: self.parse_in_python(file))
      new_manifest.save
      new_diff = RiveManifest.compare_against_previous(new_manifest.manifest, previous_manifest.manifest)
      old_diff = RiveManifest.compare_against_previous(previous_manifest.manifest, new_manifest.manifest)
      RiveManifestUpdate.new(account_id: bot.account_id, bot_id: bot_id, platform: platform, manifest_old: old_diff, manifest_new: new_diff).save
    else
      new_manifest = RiveManifest.new(account_id: bot.account_id, bot_id: bot_id, platform: platform, manifest: self.parse_in_python(file))
      new_manifest.save
    end
    new_manifest.manifest["raw_rule_clauses"].each do |rule|
      db_rule = Rule.where(account_id: bot.account_id, bot_id: bot_id, platform: platform, topic: rule["topic"], name: rule["name"], ended_at: nil).first
      if db_rule.nil?
        db_rule = Rule.new(account_id: bot.account_id, bot_id: bot_id, platform: platform, topic: rule["topic"], name: rule["name"], ended_at: nil, reply: rule["reply"].collect{|r| {reply_content: r, started_at: Time.now}}, condition: rule["condition"].collect{|c| {condition_content: c, started_at: Time.now}}, previous: rule["previous"].collect{|p| {previous_content: p, started_at: Time.now}})
      else
        db_rule.reply.each_with_index do |reply, i|
          if !rule["reply"].include?(reply)
            db_rule.reply[i][:ended_at] = Time.now
          end
        end
        db_rule.condition.each_with_index do |condition, i|
          if !rule["condition"].include?(condition)
            db_rule.condition[i][:ended_at] = Time.now
          end
        end
        db_rule.previous.each_with_index do |previous, i|
          if !rule["previous"].include?(previous)
            db_rule.previous[i][:ended_at] = Time.now
          end
        end
      end
      db_rule.save!
    end
  end

  def self.parse_in_python(file)
    digested = JSON.parse(`python scripts/rive_parser.py #{file}`)
    {
      "sub_clause" => digested["sub_clause"]["subs"], 
      "array_clauses" => digested["array_clauses"].map{|ac| {"name" => ac["name"], "include_list" => ac["include_list"]} },
      "include_clauses" => digested["include_clauses"].map{|ic| {"name" => ic["name"], "include_list" => ic["include_list"]} },
      "raw_rule_clauses" => digested["raw_rule_clauses"].map{|rrc| {"topic" => rrc["topic"], "name" => rrc["name"], "reply" => rrc["reply"], "condition" => rrc["condition"], "previous" => rrc["previous"]} }
    }
  end

  def self.compare_against_previous(previous_manifest, latest_manifest)
    first_filename = (Random.new.rand*10000000000000000).to_i.to_s(36)+".json"
    second_filename = (Random.new.rand*10000000000000000).to_i.to_s(36)+".json"
    f = File.open(first_filename, "w")
    f.write(previous_manifest.to_json)
    f.close
    f = File.open(second_filename, "w")
    f.write(latest_manifest.to_json)
    f.close
    digested = JSON.parse(`python scripts/json_differ.py #{first_filename} #{second_filename}`)
    `rm #{first_filename}`
    `rm #{second_filename}`
    {
      "sub_clause" => digested["sub_clause"]["subs"], 
      "array_clauses" => digested["array_clauses"].map{|ac| {"name" => ac["name"], "include_list" => ac["include_list"]} },
      "include_clauses" => digested["include_clauses"].map{|ic| {"name" => ic["name"], "include_list" => ic["include_list"]} },
      "raw_rule_clauses" => digested["raw_rule_clauses"].map{|rrc| {"topic" => rrc["topic"], "name" => rrc["name"], "reply" => rrc["reply"], "condition" => rrc["condition"], "previous" => rrc["previous"]} }
    }
  end
  
end
#previous_manifest = RiveManifest.parse_in_python("/Users/dgaff/Downloads/fuzzy-bot-master/lang/rive")
#latest_manifest = RiveManifest.parse_in_python("/Users/dgaff/Downloads/fuzzy-bot-master/lang/rive_altered")
#RiveManifest.ingest("/Users/dgaff/Downloads/complete-staging.rive", Bot.first.id, "facebook")