class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  has_many :google_accounts, dependent: :destroy
  has_one :active_customer_selection, dependent: :destroy
  has_many :activity_logs, dependent: :destroy

  def active_customer_id
    active_customer_selection&.customer_id
  end
end
