class Provider < ActiveRecord::Base
  
  has_many :services
  has_many :nonces
  has_many :users, inverse_of: :provider
  belongs_to :address, :class_name => :Location, :validate => true, :dependent => :destroy
  has_many :trip_tickets, :foreign_key => :origin_provider_id
  has_many :trip_claims, :foreign_key => :claimant_provider_id

  accepts_nested_attributes_for :address
  accepts_nested_attributes_for :users

  after_create :generate_initial_api_keys
  
  validates :api_key, uniqueness: true, presence: {on: :update}
  validates :private_key, presence: {on: :update}
  validates_presence_of :name, :address, :primary_contact_email
  validates :trip_ticket_expiration_days_before, :numericality => {:greater_than_or_equal_to => 0, :allow_blank => true}
  validates :trip_ticket_expiration_time_of_day, :timeliness => {:type => :time, :allow_blank => true}

  def approved_partners
    partnerships = approved_partnerships
    partner_ids = partnerships.map {|ap| ap.requesting_provider_id == id ? nil : ap.requesting_provider_id }.compact
    partner_ids = partner_ids + partnerships.map {|ap| ap.cooperating_provider_id == id ? nil : ap.cooperating_provider_id }.compact
    Provider.where(id: partner_ids.uniq)
  end

  def approved_partnerships
    partnerships = ProviderRelationship.where(
      %Q{
        (requesting_provider_id = ? OR cooperating_provider_id = ?) 
        AND approved_at IS NOT NULL
      },
      id, id
    )
    partnerships.includes(:cooperating_provider, :requesting_provider)
  end

  def pending_partnerships_initiated_by_it
    partnerships = ProviderRelationship.where(
      :requesting_provider_id => id, 
      :approved_at => nil)
    partnerships.includes(:cooperating_provider, :requesting_provider)
  end

  def partnerships_awaiting_its_approval
    partnerships = ProviderRelationship.where(
      :cooperating_provider_id => id, 
      :approved_at => nil)
    partnerships.includes(:cooperating_provider, :requesting_provider)
  end
  
  def can_auto_approve_for?(provider)
    !!((r = ProviderRelationship.find_approved_relationship_between(self, provider)) && r.provider_can_auto_approve?(self))
  end

  def regenerate_keys!(force = true)
    generate_api_key!     if force || !self.api_key.present?
    generate_private_key! if force || !self.private_key.present?
  end
  
  def generate_nonce
    begin
      nonce = SecureRandom.hex
    end while self.nonces.exists?(nonce: nonce)
    nonce
  end

  def has_any_operating_hours?
    services
      .joins(:operating_hours)
      .where('operating_hours.open_time IS NOT NULL')
      .where('operating_hours.close_time IS NOT NULL')
      .exists?
  end

  private
  
  def generate_api_key!
    begin
      api_key = SecureRandom.hex
    end while self.class.exists?(api_key: api_key)
    self.update_attribute(:api_key, api_key)
  end
  
  def generate_private_key!
    self.update_attribute(:private_key, SecureRandom.hex)
  end

  def generate_initial_api_keys
    generate_api_key! unless self.api_key.present?
    generate_private_key! unless self.private_key.present?
  end  
end
