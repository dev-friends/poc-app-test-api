require "spec_helper"

RSpec.describe "Checkboxes", app_host: "https://the-internet.herokuapp.com" do
  it "starts with the first checkbox unchecked and the second checked" do
    visit "/checkboxes"

    checkboxes = all("#checkboxes input[type=checkbox]")
    expect(checkboxes[0]).not_to be_checked
    expect(checkboxes[1]).to be_checked
  end

  it "toggles a checkbox's checked state when clicked" do
    visit "/checkboxes"

    first_checkbox = all("#checkboxes input[type=checkbox]").first
    first_checkbox.click
    expect(first_checkbox).to be_checked

    first_checkbox.click
    expect(first_checkbox).not_to be_checked
  end
end
