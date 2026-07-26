require "spec_helper"

RSpec.describe "Homepage", app_host: "https://the-internet.herokuapp.com" do
  it "loads and shows the list of available examples" do
    visit "/"
    expect(page).to have_link("Form Authentication")
  end
end
