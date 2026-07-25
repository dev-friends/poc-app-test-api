require "spec_helper"

RSpec.describe "Homepage" do
  it "loads and shows the list of available examples" do
    visit "/"
    expect(page).to have_link("Form Authentication")
  end
end
