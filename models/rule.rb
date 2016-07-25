class Rule
  include MongoMapper::Document
  key :account_id
  key :bot_id
  key :platform
  key :name
  key :reply
  key :condition
  key :previous
  key :started_at
  key :ended_at
  key :interaction_count
  key :topic
  timestamps!
  
  def self.enrich
    Rule.all.each do |rule|
    rule.interaction_count = Interaction.where(bot_rule: rule.name).count
    rule.save
    end
  end
  
  def get_good_examples(interaction_count_low, interaction_count_high, start_time, end_time)
    user_interactions = Interaction.where(platform: self.platform, bot_rule: self.name, account_id: self.account_id, bot_id: self.bot_id, :lifetime_count.gte => interaction_count_low, :lifetime_count.lte => interaction_count_high, :time.gte => start_time, :time.lte => end_time).distinct(:user_input).select{|x| cld = CLD.detect_language(x) ; cld[:reliable] && cld[:name] == "ENGLISH" && x.split(" ").length > 5}.uniq
    questions = user_interactions.select{|x| x.include?("?")}
    statements = user_interactions.select{|x| !x.include?("?")}
    tfidf_questions = questions.collect{|text| TfIdfSimilarity::Document.new(text)};false
    tfidf_statements = statements.collect{|text| TfIdfSimilarity::Document.new(text)};false
    questions_model = TfIdfSimilarity::TfIdfModel.new(tfidf_questions, :library => :narray);false
    question_scores = []
    question_term_scores = {}
    tfidf_questions.each do |question|
      tfidf_by_term = {}
      question.terms.each do |term|
        tfidf_by_term[term] = questions_model.tfidf(question, term)
        question_term_scores[term] ||= questions_model.tfidf(question, term)
      end
      question_scores << tfidf_by_term.values.average
    end
    statements_model = TfIdfSimilarity::TfIdfModel.new(tfidf_statements, :library => :narray);false
    statement_scores = []
    statement_term_scores = {}
    tfidf_statements.each do |statement|
      tfidf_by_term = {}
      statement.terms.each do |term|
        tfidf_by_term[term] = statements_model.tfidf(statement, term)
        statement_term_scores[term] ||= statements_model.tfidf(statement, term)
      end
      statement_scores << tfidf_by_term.values.average
    end
    {questions: questions.zip(question_scores).sort_by{|k,v| v}.first(10), statements: statements.zip(statement_scores).sort_by{|k,v| v}.first(10)}
  end
end