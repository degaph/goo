require 'tf-idf-similarity'
class Campaign
  include MongoMapper::Document
  key :bot_id, BSON::ObjectId
  key :rule_ids, Array
  key :platform, String
  key :campaign_type, String
  key :campaign_periodicity, Integer
  timestamps!
  
  def backfill_campaign
    first_time = Time.parse(Interaction.order(:time).first(bot_rule: Rule.where(id: self.rule_ids).collect(&:name)).time.strftime("%Y-%m-%d 00:00:00 +0000"))
    this_time = first_time
    next_time = Time.parse(first_time.strftime("%Y-%m-%d 23:59:59 +0000"))+self.campaign_periodicity
    while next_time < Time.now
      self.rules.each do |rule|
        campaign_datapoint = CampaignDatapoint.first_or_create(bot_id: self.bot_id, rule_id: rule.id, start_time: this_time, end_time: next_time)
        campaign_datapoint.content = self.send("generate_#{campaign_type}_datapoint", this_time, next_time)
        campaign_datapoint.save!
      end
      this_time += self.campaign_periodicity
      next_time += self.campaign_periodicity
    end
  end
  
  def generate_catch_all_datapoint(start_time, end_time)
    Hash[self.rules.collect{|r| [r.id.to_s, r.get_good_examples(start_time, end_time)]}]
  end
  
  def rules
    Rule.where(id: self.rule_ids).to_a
  end
end
#Rule.to_a.each do |rule|
#  c = Campaign.new(bot_id: rule.bot_id, rule_ids: [rule.id], platform: "facebook", campaign_type: "catch_all", campaign_periodicity: 24*60*60)
#  c.backfill_campaign
#end

#all_interactions = Interaction.where(:time.gte => Time.parse("2016-05-15 00:00:00"), bot_rule: "fuzzybot do lang en wildcard{weight=1}").collect(&:user_input).select{|x| x.include?("?")}
#text = "Hello world. My name is Mr. Smith. I work for the U.S. Government and I live in the U.S. I live in New York."
#require 'pragmatic_segmenter'
#require 'matrix'
#require 'tf-idf-similarity'
#questions = all_interactions.collect{|text| PragmaticSegmenter::Segmenter.new(text: text).segment};false
#sample_prob = 10000/Interaction.count.to_f
#sampled_interactions = Interaction.to_a.select{|x| rand < sample_prob}.collect(&:user_input);false
#question_data = questions.flatten.collect{|text| TfIdfSimilarity::Document.new(text)};false
#non_question_data = sampled_interactions.flatten.collect{|text| TfIdfSimilarity::Document.new(text)};false
#model = TfIdfSimilarity::TfIdfModel.new([question_data, non_question_data].flatten, :library => :narray);false
#ps.segment
#tfidf_by_term = {}
#question_data.each do |doc|
#  doc.terms.each do |term|
#    tfidf_by_term[term] ||= []
#    tfidf_by_term[term] << model.tfidf(doc, term)
#  end
#end;false
#sampled_freqs = sampled_interactions.collect{|x| x.downcase.split(" ")}.flatten.counts
#sampled_percents = Hash[sampled_freqs.collect{|k,v| [k,v/sampled_freqs.values.sum]}]
#question_freqs = questions.flatten.collect{|x| x.downcase.split(" ")}.flatten.counts
#question_percents = Hash[question_freqs.collect{|k,v| [k,v/question_freqs.values.sum]}]
#
#CLD.detect_language("This is a test")
#reliable_interactions = all_interactions.select{|x| cld = CLD.detect_language(x) ; cld[:reliable] && cld[:name] == "ENGLISH" && x.split(" ").length > 5}.uniq
#reliable_english_interactions = reliable_interactions.select{|x| CLD.detect_language(x)[:name] == "ENGLISH"}
#reliable_english_sentences = reliable_english_interactions.select{|x| x.split(" ").length > 5}
#reliable_english_sentences
#all_interactions.first
#
#
#rarities = Hash[question_percents.collect{|k,v| [k, ((sampled_percents[k]||1/sampled_freqs.values.sum)-v)**2]}]
#
#RestClient.post("https://api.meaningcloud.com/topics-2.0", "98ffe94fc006f044315441da70f0af06")
#MeaningCloud.configure do |config|
#  config.key = "98ffe94fc006f044315441da70f0af06"
#  # optional - these are the defaults
#  config.language = :en
#  config.topic_types = 'ec'
#end
#result = MeaningCloud::Topics.extract_topics(txt: gz) # Returns a hash of the parsed JSON result.
#JSON.parse(RestClient.post("https://api.meaningcloud.com/topics-1.2", {key: "98ffe94fc006f044315441da70f0af06", lang: "en", txt: reliable_english_sentences.join(" "), txtf: "plain", tt: "a"}))
#
#524
#https://www.meaningcloud.com/developer/documentation/ontology#ODTHEME_AERONAUTICS