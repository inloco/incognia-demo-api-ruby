# Incognia Demo API and Web App

[![Ruby](https://github.com/inloco/incognia-demo-api/actions/workflows/ci.yml/badge.svg)](https://github.com/inloco/incognia-demo-api/actions/workflows/ci.yml)

This is a sample API and Web app that uses [Incognia Ruby library](https://github.com/inloco/incognia-ruby) to easily integrate to Incognia API.
At this repository you can better understand:

* How you can place Incognia inside your server
* How you can leverage Incognia solution to implement Web authentication supported by a mobile device

## Available endpoints

This API responds to the below endpoints:

* Register signup: `POST /signups`
* Reassess signup: `GET /signups/:id`
* Signin: `POST /signin`
  * This endpoint uses Incognia API to decide between frictionlessly sign in the user or sending an OTP through email.
* Validate signin OTP: `POST /signin/validate_otp`
* Validate signin QR code (mobile supported Web login): `POST /signin/validate_qrcode`
* Assess user login and signup: `POST /users/:user_id/assessments/assess`
* Return user latest assessments: `GET /users/:user_id/assessments/latest`

The Web App has below pages:

* Login: `/web/session/new`
* Dashboard (signed section): `/web/dashboard`

## How to run this API locally?

### Application setup

The application requires Ruby 3.3.14. With this Ruby version in place, install `bundler` and run `bundle install` from the root of the repository.

To check if everything is fine, you can run the test suite with `rake spec`.

### Running with your organization credentials

1. Generate Incognia API credentials at Incognia dashboard
2. Set the `client_id` and `secret` at `.env` file
3. Run the server: `rails s` (API will listen at port 3000)

## How to run this API with Docker?

1. Generate Incognia API credentials at Incognia dashboard
2. Set the `client_id` and `secret` at `.env` file
3. Run Docker Compose: `docker-compose up` (API will listen at port 3000)
