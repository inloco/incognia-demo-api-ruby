FactoryBot.define do
  factory :user do
    address do
      {
        structured_address:{
          country_name: Faker::Address.country,
          country_code: Faker::Address.country_code,
          state: Faker::Address.state,
          city: Faker::Address.city,
          borough: Faker::Lorem.word,
          street: Faker::Address.street_name,
          number: Faker::Address.building_number,
          postal_code: Faker::Address.zip_code
        }
      }
    end
    incognia_signup_id { SecureRandom.uuid }
  end

  factory :signin_code do
    code { SecureRandom.base64(20) }
    expires_at { 2.minutes_from_now }
  end
end