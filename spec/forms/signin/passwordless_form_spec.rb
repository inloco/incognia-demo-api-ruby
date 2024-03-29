require 'rails_helper'

RSpec.describe Signin::PasswordlessForm, type: :model do
  subject(:form) { described_class.new(attrs) }
  let(:attrs) { {} }

  context 'validations' do
    it { should validate_presence_of(:user) }
    it { should validate_presence_of(:installation_id) }
  end

  describe '#submit' do
    subject(:submit) { form.submit }

    before do
      allow(Signin::Register).to receive(:call).and_return(login_assessment)
    end
    let(:login_assessment) { build(:incognia_assessment, risk_assessment:) }
    let(:risk_assessment) do
      attributes_for(:incognia_assessment)[:risk_assessment]
    end

    context 'when attributes are valid' do
      let(:attrs) { { user:, installation_id: } }
      let(:user) { build(:user) }
      let(:installation_id) { SecureRandom.uuid }

      it 'registers login with account_id and installation_id' do
        expect(Signin::Register).to receive(:call).with(user:, installation_id:)

        submit
      end

      context 'and Incognia API returns low risk' do
        let(:risk_assessment) { 'low_risk' }

        it 'returns the user' do
          expect(submit).to eq(user)
        end
      end

      shared_examples_for 'generate and send otp code to email' do |risk_assessment|
        context "when Incognia API returns #{risk_assessment}" do
          let(:risk_assessment) { risk_assessment }
          let(:code) { SecureRandom.base64(20) }
          let(:message_delivery) { instance_double(ActionMailer::MessageDelivery) }

          before do
            allow(Signin::GenerateSigninCode).to receive(:call).with(user: user).
              and_return(code)
          end

          it 'invokes generate signin code service' do
            expect(Signin::GenerateSigninCode).to receive(:call).with(user: user).
              and_return(code)

            submit
          end

          it 'sends email with generated code' do
            expect(SessionMailer).to receive(:otp_email)
              .with(recipient: user.email, otp_code: code)
              .and_return(message_delivery)

            expect(message_delivery).to receive(:deliver_later)

            submit
          end

          it 'returns nil' do
            expect(submit).to be_nil
          end
        end
      end

      it_behaves_like 'generate and send otp code to email', :high_risk
      it_behaves_like 'generate and send otp code to email', :unknown_risk
    end

    context 'when attributes are invalid' do
      let(:params) { {} }

      it 'does not register login' do
        expect(Signin::Register).to_not receive(:call)

        submit
      end

      it 'does not generate a signin code' do
        expect(Signin::GenerateSigninCode).to_not receive(:call)

        submit
      end

      it 'does not send email with generated code' do
        expect(SessionMailer).to_not receive(:otp_email)
      end

      it 'returns falsy' do
        expect(submit).to be_falsy
      end
    end
  end
end
