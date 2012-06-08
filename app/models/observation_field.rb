class ObservationField < ActiveRecord::Base
  belongs_to :user
  has_many :observation_field_values, :dependent => :destroy
  has_many :observations, :through => :observation_field_values
  
  validates_uniqueness_of :name
  validates_presence_of :name
  
  before_validation :strip_tags
  before_validation :strip_name
  before_validation :strip_description
  before_validation :strip_allowed_values
  validate :allowed_values_has_pipes
  
  # TYPES = %w(text numeric date time datetime location)
  TYPES = %w(text numeric date time)
  
  def strip_name
    self.name = name.strip unless name.blank?
    true
  end
  
  def strip_description
    self.description = description.strip unless description.blank?
    true
  end
  
  def strip_allowed_values
    return true if allowed_values.blank?
    self.allowed_values = allowed_values.split('|').map{|v| v.strip}.join('|')
    true
  end
  
  # usually we would sanitize on the front, but we use these values in json a 
  # lot, so it's safer to do it here
  def strip_tags
    %w(name description allowed_values).each do |a|
      next if send(a).blank?
      self.send "#{a}=", send(a).gsub(/\<.*?\>/, '')
    end
    true
  end
  
  def allowed_values_has_pipes
    return true if allowed_values.blank?
    if allowed_values.split('|').size < 2
      errors.add(:allowed_values, "must have multiple values separated by pipes")
    end
    true
  end
end
