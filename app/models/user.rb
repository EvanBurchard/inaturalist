require 'digest/sha1'

class User < ActiveRecord::Base
  
  # If the user has this role, has_role? will always return true
  JEDI_MASTER_ROLE = 'admin'
  
  include Authentication
  include Authentication::ByPassword
  include Authentication::ByCookieToken
  include Authorization::AasmRoles
  
  # serialize :preferences, Preferences
  
  # belongs_to :life_list, :dependent => :destroy
#   has_one  :flickr_identity, :dependent => :destroy
#   has_one  :picasa_identity, :dependent => :destroy
  has_many :observations, :dependent => :destroy
  
  # Some interesting ways to map self-referential relationships in rails
#   has_many :friendships, :dependent => :destroy
#   has_many :friends, :through => :friendships
#   has_many :stalkerships, :class_name => 'Friendship', :foreign_key => 'friend_id', :dependent => :destroy
#   has_many :followers, :through => :stalkerships,  :source => 'user'
  
#   has_many :activity_stream_updates, :class_name => 'ActivityStream', :dependent => :destroy
#   has_many :activity_streams, :foreign_key => 'subscriber_id'
  
#   has_many :lists, :dependent => :destroy
#   has_many :identifications, :dependent => :destroy
#   has_many :photos, :dependent => :destroy
#   has_many :goal_participants, :dependent => :destroy
#   has_many :goals, :through => :goal_participants
#   has_many :incomplete_goals,
#            :source =>  :goal,
#            :through => :goal_participants,
#            :conditions => ["goal_participants.goal_completed = 0 " + 
#                            "AND goals.completed = 0 " +
#                            "AND (goals.ends_at IS NULL " +
#                            "OR goals.ends_at > ?)", Time.now]
#   has_many :completed_goals,
#            :source => :goal,
#            :through => :goal_participants,
#            :conditions => "goal_participants.goal_completed = 1 " +
#                           "OR goals.completed = 1"
#   has_many :goal_participants_for_incomplete_goals,
#            :class_name => "GoalParticipant",
#            :include => :goal,
#            :conditions => ["goal_participants.goal_completed = 0 " + 
#                            "AND goals.completed = 0 " +
#                            "AND (goals.ends_at IS NULL " +
#                            "OR goals.ends_at > ?)", Time.now]
#   has_many :goal_contributions, :through => :goal_participants
  
#   has_many :posts, :dependent => :destroy
#   has_many :journal_posts, :class_name => Post.to_s, :as => :parent
#   has_many :taxon_links, :dependent => :nullify
#   has_many :comments, :dependent => :destroy
#   has_many :projects, :dependent => :destroy
#   has_many :project_users, :dependent => :destroy
#   has_many :listed_taxa, :dependent => :nullify
  
  has_attached_file :icon, 
    :styles => { :medium => "300x300>", :thumb => "48x48#", :mini => "16x16#" },
    :path => ":rails_root/public/attachments/:class/:attachment/:id/:style/:basename.:extension",
    :url => "/attachments/:class/:attachment/:id/:style/:basename.:extension",
    :default_url => "/attachment_defaults/:class/:attachment/defaults/:style.png"

  # Roles
  has_and_belongs_to_many :roles

  before_create :create_preferences
  after_create :create_life_list, :signup_for_incomplete_community_goals
  after_destroy :create_deleted_user
              
  validates_presence_of     :login
  validates_length_of       :login,    :within => 3..40
  validates_uniqueness_of   :login
  validates_format_of       :login,    :with => Authentication.login_regex, :message => Authentication.bad_login_message

  validates_format_of       :name,     :with => Authentication.name_regex,  :message => Authentication.bad_name_message, :allow_nil => true
  validates_length_of       :name,     :maximum => 100

  validates_presence_of     :email
  validates_length_of       :email,    :within => 6..100 #r@a.wk
  validates_uniqueness_of   :email
  validates_format_of       :email,    :with => Authentication.email_regex, :message => Authentication.bad_email_message  

  # HACK HACK HACK -- how to do attr_accessible from here?
  # prevents a user from submitting a crafted form that bypasses activation
  # anything else you want your user to change should be added here.
  attr_accessible :login, :email, :name, :password, :password_confirmation, :icon, :description, :time_zone
  
  
  named_scope :order, Proc.new { |sort_by, sort_dir|
    sort_dir ||= 'DESC'
    {:order => ("%s %s" % [sort_by, sort_dir])}
  }
  
  def self.query(params={}) 
    scope = self.scoped({})
    if params[:sort_by] && params[:sort_dir]
      scope.order(params[:sort_by], params[:sort_dir])
    elsif params[:sort_by]
      params.order(query[:sort_by])
    end
    scope
  end
  
  

  # Authenticates a user by their login name and unencrypted password.  Returns the user or nil.
  #
  # uff.  this is really an authorization, not authentication routine.  
  # We really need a Dispatch Chain here or something.
  # This will also let us return a human error message.
  #
  def self.authenticate(login, password)
    return nil if login.blank? || password.blank?
    u = find_in_state :first, :active, :conditions => {:login => login}
    u = find_in_state :first, :active, :conditions => {:email => login} if u.nil?
    u && u.authenticated?(password) ? u : nil
  end

  def login=(value)
    write_attribute :login, (value ? value.downcase : nil)
  end

  def email=(value)
    write_attribute :email, (value ? value.downcase : nil)
  end
  
  # Role related methods
  
  # Checks if a user has a role; returns true if they don't but
  # are admin.  Admins are supreme beings
  def has_role?(role)
    role_list ||= roles.map(&:name)
    role_list.include?(role.to_s) || role_list.include?(User::JEDI_MASTER_ROLE)
  end

  # Everything below here was added for iNaturalist
  
  # TODO: named_scope
  def recent_observations(num = 5)
    observations.find(:all, :limit => num, :order => "created_at DESC")
  end

  # TODO: named_scope  
  def friends_observations(limit = 5)
    obs = []
    friends.each do |friend|
      obs << friend.observations.find(:all, :order => 'created_at DESC', :limit => limit)
    end
    obs.flatten
  end
  
  
  # TODO: named_scope / roles plugin
  def is_curator?
    has_role?(:curator)
  end
  
  def is_admin?
    has_role?(:admin)
  end
  
  def to_s
    "<User #{self.id}: #{self.login}>"
  end
  
  def friends_with?(user)
    friends.exists?(user)
  end

  protected
  def make_activation_code
    self.deleted_at = nil
    self.activation_code = self.class.make_token
  end
  
  # Everything below here was added for iNaturalist
  def create_life_list
    life_list = LifeList.create(:user => self)
    self.life_list = life_list
    self.save
  end
  
  def signup_for_incomplete_community_goals
    goals << Goal.for('community').incomplete.find(:all)
  end
  
  def create_preferences
    self.preferences ||= Preferences.new
  end
  
  def create_deleted_user
    DeletedUser.create(
      :user_id => id,
      :login => login,
      :email => email,
      :user_created_at => created_at,
      :user_updated_at => updated_at,
      :observations_count => observations_count
    )
    true
  end
end
