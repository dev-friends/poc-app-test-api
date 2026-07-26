require "spec_helper"
require_relative "../support/cpf_generator"

RSpec.describe "Registration", app_host: "http://host.docker.internal:3001" do
  def unique_email
    "user_#{Time.now.to_i}_#{rand(1_000_000)}@example.com"
  end

  def fill_registration_form(first_name: "Ana", last_name: "Silva", email: unique_email,
                              password: "SuperSecret123", password_confirmation: password,
                              cpf: CpfGenerator.generate, accept_terms: true)
    visit "/registrations/new"
    fill_in "user_first_name", with: first_name
    fill_in "user_last_name", with: last_name
    fill_in "user_email_address", with: email
    fill_in "user_password", with: password
    fill_in "user_password_confirmation", with: password_confirmation
    fill_in "user_cpf", with: cpf
    check "user_terms_of_use" if accept_terms
    email
  end

  it "creates an account with valid data and redirects to the signed-in home page" do
    email = fill_registration_form(first_name: "Ana", last_name: "Silva")
    click_button "Cadastrar"

    expect(page).to have_current_path("/home")
    expect(page).to have_content("Cadastro realizado com sucesso!")
    expect(page).to have_content("Olá, Ana!")
    expect(page).to have_content(email)
  end

  it "does not submit while required fields (including terms acceptance) are blank" do
    visit "/registrations/new"
    click_button "Cadastrar"

    # The browser's native HTML5 validation blocks the request entirely
    # (email/password/password confirmation/cpf/terms are all `required`),
    # so the page never navigates away from the form.
    expect(page).to have_current_path("/registrations/new")
    expect(page).to have_no_content("Cadastro realizado com sucesso!")

    invalid = page.evaluate_script("document.getElementById('user_terms_of_use').validity.valid")
    expect(invalid).to eq(false)
  end

  it "rejects a password confirmation that doesn't match" do
    fill_registration_form(password: "SuperSecret123", password_confirmation: "SomethingElse123")
    click_button "Cadastrar"

    expect(page).to have_current_path("/registrations/new")
    expect(page).to have_content("Password confirmation doesn't match Password")
  end

  it "rejects a password shorter than 8 characters" do
    fill_registration_form(password: "short1", password_confirmation: "short1")
    click_button "Cadastrar"

    expect(page).to have_current_path("/registrations/new")
    expect(page).to have_content("Password is too short (minimum is 8 characters)")
  end

  it "rejects a CPF with an invalid check digit" do
    fill_registration_form(cpf: "111.111.111-11")
    click_button "Cadastrar"

    expect(page).to have_current_path("/registrations/new")
    expect(page).to have_content("Cpf inválido")
  end

  it "rejects a second registration reusing the same email and CPF" do
    email = unique_email
    cpf = CpfGenerator.generate

    fill_registration_form(email: email, cpf: cpf)
    click_button "Cadastrar"
    expect(page).to have_current_path("/home")

    fill_registration_form(first_name: "Outra", last_name: "Pessoa", email: email, cpf: cpf)
    click_button "Cadastrar"

    expect(page).to have_current_path("/registrations/new")
    expect(page).to have_content("Email address has already been taken")
    expect(page).to have_content("Cpf has already been taken")
  end
end
