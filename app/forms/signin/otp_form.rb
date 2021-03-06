module Signin
  class OtpForm
    include ActiveModel::Model
    include Signin::CodeValidations

    attr_accessor :user, :code

    validates :user, presence: true

    def submit
      return if invalid?

      signin_code.update(used_at: Time.now)

      user
    end

    private

    def signin_code
      @signin_code ||= SigninCode.find_by(user:, code:)
    end
  end
end
