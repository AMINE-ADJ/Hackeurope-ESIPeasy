# Multi-tier authentication model
# Roles: gamer, datacenter, energy_recycler, ai_developer, admin
class User < ApplicationRecord
  has_secure_password validations: false

  belongs_to :organization, optional: true

  ROLES = %w[gamer datacenter energy_recycler ai_developer admin].freeze

  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :name, presence: true
  validates :role, inclusion: { in: ROLES }

  scope :providers, -> { where(role: %w[gamer datacenter energy_recycler]) }
  scope :consumers, -> { where(role: "ai_developer") }
  scope :admins, -> { where(role: "admin") }
  scope :active, -> { where(active: true) }

  before_create :generate_api_token

  # Role predicates
  def gamer?;           role == "gamer"; end
  def datacenter?;      role == "datacenter"; end
  def energy_recycler?; role == "energy_recycler"; end
  def ai_developer?;    role == "ai_developer"; end
  def admin?;           role == "admin"; end

  def provider?
    gamer? || datacenter? || energy_recycler?
  end

  def consumer?
    ai_developer?
  end

  def display_role
    role.titleize.gsub("Ai", "AI")
  end

  private

  def generate_api_token
    self.api_token ||= SecureRandom.hex(32)
  end
end
