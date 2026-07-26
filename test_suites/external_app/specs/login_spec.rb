require "spec_helper"

RSpec.describe "Login", app_host: "https://the-internet.herokuapp.com" do
  it "authenticates with valid credentials" do
    visit "/login"
    fill_in "username", with: "tomsmith"
    fill_in "password", with: "SuperSecretPassword!"
    click_button "Login"
    expect(page).to have_content("You logged into a secure area")
  end

  it "rejects invalid credentials (deliberately failing example)" do
    visit "/login"
    fill_in "username", with: "tomsmith"
    fill_in "password", with: "wrong-password"
    click_button "Login"
    # Deliberately fails: demonstrates how an error shows up in
    # GET /test_runs/:id/results (error_message + backtrace).
    expect(page).to have_content("this-text-does-not-exist-on-purpose")
  end
end
