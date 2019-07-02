require 'rails_helper'

describe DiscourseEmailIncludeAddress::ActionsController do
  before do
    Jobs.run_immediately!
  end

  it 'can list' do
    sign_in(Fabricate(:user))
    get "/discourse-email-include-address/list.json"
    expect(response.status).to eq(200)
  end
end
