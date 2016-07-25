class UpdateRuleTooltip
  include Sidekiq::Worker
  sidekiq_options :queue => :cyrano_updates
  def perform(rule_id)
    RuleTooltip.update_rule(rule_id)
  end
end