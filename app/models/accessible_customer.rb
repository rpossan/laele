class AccessibleCustomer < ApplicationRecord
  belongs_to :google_account

  validates :customer_id, presence: true

  scope :ordered, -> { order(:display_name) }
  scope :active, -> { where(active: true) }
  scope :inactive, -> { where(active: false) }

  def effective_display_name
    # Priority: custom_name > display_name > formatted customer_id
    custom_name.presence || display_name.presence || formatted_customer_id
  end

  def formatted_customer_id
    digits = customer_id.to_s
    "#{digits[0..2]}-#{digits[3..5]}-#{digits[6..-1]}"
  end

  def needs_name?
    custom_name.blank? && display_name.blank?
  end

  def activate!
    update!(active: true)
  end

  def deactivate!
    update!(active: false)
  end
end

