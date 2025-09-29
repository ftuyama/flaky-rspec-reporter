require 'rails_helper'

RSpec.describe User, type: :model do
  describe 'validations' do
    it 'requires a name' do
      user = User.new(email: 'test@example.com')
      expect(user).not_to be_valid
      expect(user.errors[:name]).to include("can't be blank")
    end

    it 'requires an email' do
      user = User.new(name: 'Test User')
      expect(user).not_to be_valid
      expect(user.errors[:email]).to include("can't be blank")
    end

    it 'requires a valid email format' do
      user = User.new(name: 'Test User', email: 'invalid-email')
      expect(user).not_to be_valid
      expect(user.errors[:email]).to include("is invalid")
    end

    it 'accepts valid user data' do
      user = User.new(name: 'Test User', email: 'test@example.com')
      expect(user).to be_valid
    end
  end

  describe '#full_name' do
    it 'returns the concatenated first and last name' do
      user = User.new(first_name: 'John', last_name: 'Doe')
      expect(user.full_name).to eq('John Doe')
    end

    it 'handles missing first name' do
      user = User.new(last_name: 'Doe')
      expect(user.full_name).to eq('Doe')
    end

    it 'handles missing last name' do
      user = User.new(first_name: 'John')
      expect(user.full_name).to eq('John')
    end
  end
end