module RandomField
  extend ActiveSupport::Concern

  included do
    key :_random, Float, :default => rand
    before_save :set_random_field
  end

  module ClassMethods
    def sample(conditions={}, limit=100)
      self.where(conditions).order(:_random).limit(limit)
    end
  end

  module InstanceMethods
    def set_random_field
      self._random = rand
    end
  end
end