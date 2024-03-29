require 'rails_helper'

RSpec.describe "Sessions", type: :request do
  describe "POST /create" do
    subject(:dispatch_request) { post "/signin", params:, headers: }
    let(:params) { { account_id: user.account_id } }
    let(:user) { create(:user) }
    let(:headers) do
      {
        "ACCEPT" => "application/json",
        SignupsController::INCOGNIA_INSTALLATION_ID_HEADER => installation_id
      }
    end
    let(:installation_id) { SecureRandom.hex }

    context 'when user does not exist' do
      let(:user) { build(:user) }

      it 'returns http not found' do
        dispatch_request

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when validations succeed' do
      before do
        allow(Signin::PasswordlessForm).to receive(:new)
          .with(user:, installation_id:)
          .and_return(form)
      end
      let(:form) { instance_double(Signin::PasswordlessForm, errors: []) }

      context 'and the form returns the user' do
        before { allow(form).to receive(:submit).and_return(user) }

        it "invokes passwordless signin form" do
          allow(Signin::PasswordlessForm).to receive(:new)
            .with(user:, installation_id:)
            .and_return(form)

          expect(form).to receive(:submit)

          dispatch_request
        end

        it "returns http success" do
          dispatch_request

          expect(response).to have_http_status(:success)
        end

        it "returns registered signup as JSON" do
          dispatch_request

          expect(response.body).to eq(SessionSerializer.new(user:).to_json)
        end
      end

      context 'but the form returns nil' do
        before { allow(form).to receive(:submit).and_return(nil) }

        it "returns http unauthorized" do
          dispatch_request

          expect(response).to have_http_status(:unauthorized)
        end

        it "returns otp required message" do
          dispatch_request

          parsed_body = JSON.parse(response.body).deep_symbolize_keys
          expect(parsed_body).to have_key(:otp_required)
          expect(parsed_body.dig(:otp_required)).to eq(true)
        end
      end

      it_behaves_like 'handle Incognia API errors' do
        let(:service) { form }
        let(:method) { :submit }
      end
    end

    context 'when validations fails' do
      before do
        allow_any_instance_of(Signin::PasswordlessForm).to receive(:submit)
          .and_return(nil)

        allow_any_instance_of(Signin::PasswordlessForm).to receive(:errors)
          .and_return(form_errors)
      end
      let(:form_errors) do
        Signin::PasswordlessForm
          .new
          .errors
          .tap { |e| e.add(attribute, message) }
      end
      let(:attribute) { :installation_id }
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

  describe "POST /validate_otp" do
    subject(:dispatch_request) { post "/signin/validate_otp", params: }
    let(:params) { { account_id: user.account_id, code: } }
    let(:code) { signin_code.code }
    let(:user) { signin_code.user }
    let(:signin_code) { create(:signin_code) }

    context 'when validations succeed' do
      before do
        allow(Signin::OtpForm).to receive(:new).with(user:, code:)
          .and_return(form)
      end
      let(:form) { instance_double(Signin::OtpForm, errors: []) }

      context 'and the form returns the logged in user' do
        before { allow(form).to receive(:submit).and_return(user) }

        it "invokes otp signin form" do
          allow(Signin::OtpForm).to receive(:new).with(user:, code:)
            .and_return(form)

          expect(form).to receive(:submit)

          dispatch_request
        end

        it "returns http success" do
          dispatch_request

          expect(response).to have_http_status(:success)
        end

        it "returns logged in session as JSON" do
          dispatch_request

          expect(response.body).to eq(SessionSerializer.new(user:).to_json)
        end
      end

      context 'but the form returns nil' do
        before { allow(form).to receive(:submit).and_return(nil) }

        it "returns http unauthorized" do
          dispatch_request

          expect(response).to have_http_status(:unauthorized)
        end
      end
    end

    context 'when validations fails' do
      before do
        allow_any_instance_of(Signin::OtpForm).to receive(:submit)
          .and_return(nil)

        allow_any_instance_of(Signin::OtpForm).to receive(:errors)
          .and_return(form_errors)
      end
      let(:form_errors) do
        Signin::OtpForm
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

  describe "POST /validate_qrcode" do
    subject(:dispatch_request) { post "/signin/validate_qrcode", params: }
    let(:params) { { account_id: user.account_id, code: } }
    let(:code) { signin_code.code }
    let(:user) { signin_code.user }
    let(:signin_code) { create(:signin_code) }

    context 'when validations succeed' do
      before do
        allow(Signin::ValidateMobileTokenForm).to receive(:new)
          .with(user:, code:)
          .and_return(form)
      end
      let(:form) do
        instance_double(
          Signin::ValidateMobileTokenForm,
          signin_code: signin_code,
          errors: []
        )
      end

      it "invokes validate mobile token form" do
        expect(form).to receive(:submit)

        dispatch_request
      end

      context 'and the form returns the generated web OTP code' do
        before { allow(form).to receive(:submit).and_return(web_otp_code) }
        let(:web_otp_code) { create(:signin_code).code }

        it "broadcasts to signin channel" do
          expect { dispatch_request }.to have_broadcasted_to(signin_code)
            .with(
              url: validate_otp_web_session_url,
              email: user.email,
              code: web_otp_code
            )
            .from_channel(SigninChannel)

          dispatch_request
        end

        it "returns http success" do
          dispatch_request

          expect(response).to have_http_status(:success)
        end
      end

      context 'but the form returns nil' do
        before { allow(form).to receive(:submit).and_return(nil) }

        it "returns http unauthorized" do
          dispatch_request

          expect(response).to have_http_status(:unauthorized)
        end
      end
    end

    context 'when validations fails' do
      before do
        allow_any_instance_of(Signin::ValidateMobileTokenForm).to receive(:submit)
          .and_return(nil)

        allow_any_instance_of(Signin::ValidateMobileTokenForm).to receive(:errors)
          .and_return(form_errors)
      end
      let(:form_errors) do
        Signin::ValidateMobileTokenForm
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
end
