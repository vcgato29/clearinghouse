# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :trip_ticket_comment do
    trip_ticket
    user
    body "My Comment"
  end
end
