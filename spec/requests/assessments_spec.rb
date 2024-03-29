require 'rails_helper'

RSpec.describe "Assessments", type: :request do
  describe "POST /users/:user_id/assessments/assess" do
    subject(:dispatch_request) do
      post "/users/#{user.account_id}/assessments/assess", headers:
    end
    let(:user) { create(:user) }
    let(:headers) do
      {
        "ACCEPT" => "application/json",
        SignupsController::INCOGNIA_INSTALLATION_ID_HEADER => installation_id
      }
    end
    let(:installation_id) { SecureRandom.hex }

    before do
      allow(Assessments::AssessForm).to receive(:new).and_return(form)
    end
    let(:form) do
      instance_double(
        Assessments::AssessForm,
        errors: form_errors,
        submit: submit_return
      )
    end
    let(:form_errors) { [] }
    let(:submit_return) { nil }

    context 'when user does not exist' do
      let(:user) { build(:user) }

      it 'returns http not found' do
        dispatch_request

        expect(response).to have_http_status(:not_found)
      end
    end

    context 'when validations succeed' do
      let(:submit_return) { assessments }
      let(:assessments) { build_list(:assessment_log, 2) }

      it "invokes assess form" do
        expect(Assessments::AssessForm).to receive(:new)
          .with(user:, installation_id:)
          .and_return(form)

        expect(form).to receive(:submit)

        dispatch_request
      end


      it "returns http success" do
        dispatch_request

        expect(response).to have_http_status(:success)
      end

      it "returns requested assessments as JSON" do
        dispatch_request

        serializable_assessments = assessments.map do |assessment|
          AssessmentSerializer.new(assessment:)
        end

        expect(response.body).to eq(serializable_assessments.to_json)
      end

      it_behaves_like 'handle Incognia API errors' do
        let(:service) { form }
        let(:method) { :submit }
      end
    end

    context 'when validations fails' do
      let(:form_errors) do
        Assessments::AssessForm
          .new
          .errors
          .tap { |e| e.add(attribute, message) }
      end
      let(:attribute) { :user }
      let(:message) { 'cant be blank' }

      it "returns http unprocessable entity" do
        dispatch_request

        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "returns detailed errors" do
        dispatch_request

        parsed_body = JSON.parse(response.body).deep_symbolize_keys
        expect(parsed_body).to have_key(:errors)
        expect(parsed_body.dig(:errors, attribute)).to include(message)
      end
    end
  end

  describe "GET /users/:user_id/assessments/latest" do
    subject(:dispatch_request) do
      get "/users/#{user.account_id}/assessments/latest", headers:
    end
    let(:user) { create(:user) }
    let(:headers) do
      {
        "ACCEPT" => "application/json",
        SignupsController::INCOGNIA_INSTALLATION_ID_HEADER => installation_id
      }
    end
    let(:installation_id) { SecureRandom.hex }

    before do
      allow(Assessments::GetLatestAssessmentLogs).to receive(:call)
        .and_return(latest_assessments)
    end
    let(:latest_assessments) { build_list(:assessment_log, 2) }

    it "returns http success" do
      dispatch_request

      expect(response).to have_http_status(:success)
    end

    it "fetches last assessments" do
      expect(Assessments::GetLatestAssessmentLogs).to receive(:call)
        .with(user:, installation_id:)

      dispatch_request
    end

    it "returns latest assessments as JSON" do
      dispatch_request

      serializable_assessments = latest_assessments.map do |assessment|
        AssessmentSerializer.new(assessment:)
      end

      expect(response.body).to eq(serializable_assessments.to_json)
    end

    context 'when user does not exist' do
      let(:user) { build(:user) }

      it 'returns http not found' do
        dispatch_request

        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
