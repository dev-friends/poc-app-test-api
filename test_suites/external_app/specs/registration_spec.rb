require "spec_helper"
require "securerandom"

# NOTE ON HOW THIS SUITE WAS WRITTEN
# -----------------------------------
# http://localhost:3001 is not reachable from the sandbox that generated
# this file (nothing listens on that port here, and this container is
# isolated from whatever host/network serves the real registration form).
# So instead of hard-coding selectors guessed from a specific markup, the
# form is located defensively:
#   - the email input via `type=email` (or a name/id containing "email")
#   - password inputs via `type=password`, in DOM order (1st = password,
#     2nd = confirmation, if one exists)
#   - an optional "name"-like text field, filled only if present
#   - the submit control via `type=submit` (falls back to any button)
# Validation-error assertions match common English/Portuguese phrasing
# with a regexp rather than one exact string, since we don't know the
# app's locale or copy. Run this against the real form and tighten the
# locators/copy once it's confirmed reachable.
RSpec.describe "Registration", app_host: "http://localhost:3001" do
  let(:valid_password) { "SuperSecret123!" }

  def unique_email
    "test.user.#{SecureRandom.hex(6)}@example.com"
  end

  def email_field
    find("input[type='email'], input[name*='email' i], input[id*='email' i]")
  end

  def password_fields
    all("input[type='password']")
  end

  def submit_form
    find("input[type='submit'], button[type='submit'], form button").click
  end

  def fill_name_if_present(name: "Test User")
    if page.has_field?("Name", type: "text")
      fill_in "Name", with: name
      return
    end

    field = page.all("input[type='text'][name*='name' i]").first
    field&.set(name)
  end

  def fill_registration_form(email:, password: valid_password, password_confirmation: password)
    fill_name_if_present
    email_field.set(email)

    fields = password_fields
    fields[0]&.set(password)
    fields[1]&.set(password_confirmation) if fields.size > 1
  end

  before { visit "/registrations/new" }

  it "renders a registration form with email and password fields" do
    expect(page).to have_selector("form")
    expect(page).to have_selector("input[type='email'], input[name*='email' i]")
    expect(password_fields.size).to be >= 1
  end

  it "successfully registers a user with valid, unique data" do
    fill_registration_form(email: unique_email)
    submit_form

    expect(current_path).not_to eq("/registrations/new")
  end

  it "re-renders the form with an error when required fields are left blank" do
    submit_form

    expect(current_path).to eq("/registrations/new")
    expect(page).to have_content(/can't be blank|is required|obrigat[óo]rio|preench/i)
  end

  it "rejects an invalid email format" do
    fill_registration_form(email: "not-an-email")
    submit_form

    expect(current_path).to eq("/registrations/new")
    expect(page).to have_content(/invalid|inv[áa]lido/i)
  end

  it "rejects a password confirmation that does not match the password" do
    skip "form has no password confirmation field" if password_fields.size < 2

    fill_registration_form(email: unique_email, password_confirmation: "SomethingElse456!")
    submit_form

    expect(current_path).to eq("/registrations/new")
    expect(page).to have_content(/doesn.t match|does not match|n[ãa]o (corresponde|confere)/i)
  end

  it "prevents registering twice with the same email" do
    email = unique_email

    fill_registration_form(email: email)
    submit_form

    visit "/registrations/new"
    fill_registration_form(email: email)
    submit_form

    expect(current_path).to eq("/registrations/new")
    expect(page).to have_content(/already been taken|already (in use|registered|exists)|j[áa] (est[áa] em uso|cadastrado|existe)/i)
  end
end
