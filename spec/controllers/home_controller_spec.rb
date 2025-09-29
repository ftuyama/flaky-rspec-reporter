require 'rails_helper'

RSpec.describe HomeController, type: :controller do
  describe 'GET #index' do
    it 'returns a success response' do
      get :index
      expect(response).to be_successful
    end

    it 'assigns @message' do
      get :index
      expect(assigns(:message)).to eq("Welcome to Flaky RSpec Reporter Demo")
    end
  end
end