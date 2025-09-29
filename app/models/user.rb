class User < ApplicationRecord
  validates :name, presence: true
  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }

  def full_name
    "#{first_name} #{last_name}".strip
  end

  def self.random_user
    names = ['Alice', 'Bob', 'Charlie', 'Diana', 'Eve']
    User.new(
      name: names.sample,
      email: "#{names.sample.downcase}@example.com",
      first_name: names.sample,
      last_name: names.sample
    )
  end
end