require 'test_helper'
require 'api_param_factory'

describe "Clearinghouse::API_v1 trip tickets endpoints" do
  before do
    @provider = FactoryGirl.create(:provider)
    @trip_ticket1 = FactoryGirl.create(:trip_ticket, customer_first_name: "Dom", originator: @provider, origin_trip_id: 'origintrip1', updated_at: Time.zone.parse("2013-01-01 00:00"))
    @trip_ticket2 = FactoryGirl.create(:trip_ticket, customer_first_name: "Arthur", originator: @provider, origin_trip_id: 'origintrip2', updated_at: Time.zone.parse("2013-01-01 12:00"))
    @trip_ticket3 = FactoryGirl.create(:trip_ticket, customer_first_name: "Mal", originator: FactoryGirl.create(:provider), origin_trip_id: 'origintrip3', updated_at: Time.zone.parse("2013-01-01 23:00"))
  end

  describe "GET /api/v1/trip_tickets" do
    include_examples "requires authenticatable params"

    it "should return all trip tickets originated by the provider as JSON" do
      get "/api/v1/trip_tickets", api_params(@provider)
      response.status.must_equal 200
      response.body.must_include %Q{"customer_first_name":"#{@trip_ticket1.customer_first_name}"}
      response.body.must_include %Q{"customer_first_name":"#{@trip_ticket2.customer_first_name}"}
      response.body.wont_include %Q{"customer_first_name":"#{@trip_ticket3.customer_first_name}"}
    end

    it "should support trip ticket filters" do
      filter_params = { trip_ticket_filters: { customer_name: "Arthur" }}
      get "/api/v1/trip_tickets", api_params(@provider, filter_params)
      response.status.must_equal 200
      response.body.wont_include %Q{"customer_first_name":"#{@trip_ticket1.customer_first_name}"}
      response.body.must_include %Q{"customer_first_name":"#{@trip_ticket2.customer_first_name}"}
      response.body.wont_include %Q{"customer_first_name":"#{@trip_ticket3.customer_first_name}"}
    end
  end

  describe "GET /api/v1/trip_tickets/sync" do
    include_examples "requires authenticatable params"

    it "should return all trip tickets originated or claimed by the provider as JSON" do
      FactoryGirl.create(:trip_claim, :trip_ticket => @trip_ticket3, :claimant => @provider)
      get "/api/v1/trip_tickets/sync", api_params(@provider)
      response.status.must_equal 200
      response.body.must_include %Q{"customer_first_name":"#{@trip_ticket1.customer_first_name}"}
      response.body.must_include %Q{"customer_first_name":"#{@trip_ticket2.customer_first_name}"}
      response.body.must_include %Q{"customer_first_name":"#{@trip_ticket3.customer_first_name}"}
    end

    it "should return detailed trip tickets with associated objects nested" do
      FactoryGirl.create(:trip_claim, :trip_ticket => @trip_ticket3, :claimant => @provider)
      user = FactoryGirl.create(:user, provider: @provider)
      FactoryGirl.create(:trip_ticket_comment, trip_ticket: @trip_ticket1, user: user, body: "a comment")
      get "/api/v1/trip_tickets/sync", api_params(@provider)
      response.status.must_equal 200
      response.body.must_include %Q("originator":{)
      response.body.must_include %Q("pick_up_location":{)
      response.body.must_include %Q("drop_off_location":{)
      response.body.must_include %Q("trip_result":null)
      response.body.must_include %Q("trip_claims":[)
      response.body.must_include %Q("trip_ticket_comments":[)
    end

    it "should return optional nested objects, when present" do
      @trip_ticket1.customer_address = FactoryGirl.create(:location)
      @trip_ticket1.save
      get "/api/v1/trip_tickets/sync", api_params(@provider)
      response.status.must_equal 200
      response.body.must_include %Q("customer_address":{)
    end

    it "should include a field indicating which trips are originated by the requesting provider" do
      get "/api/v1/trip_tickets/sync", api_params(@provider)
      response.status.must_equal 200
      response.body.must_include %Q("is_originator":true)
    end

    it "should accept an updated_since parameter to filter by date" do
      filter_params = { updated_since: Time.zone.parse("2013-01-01 00:01") }
      get "/api/v1/trip_tickets/sync", api_params(@provider, filter_params)
      response.status.must_equal 200
      response.body.wont_include %Q{"customer_first_name":"#{@trip_ticket1.customer_first_name}"}
      response.body.must_include %Q{"customer_first_name":"#{@trip_ticket2.customer_first_name}"}
      response.body.wont_include %Q{"customer_first_name":"#{@trip_ticket3.customer_first_name}"}
    end

    it "should support normal trip ticket filters" do
      filter_params = { trip_ticket_filters: { customer_name: "Arthur" }}
      get "/api/v1/trip_tickets/sync", api_params(@provider, filter_params)
      response.status.must_equal 200
      response.body.wont_include %Q{"customer_first_name":"#{@trip_ticket1.customer_first_name}"}
      response.body.must_include %Q{"customer_first_name":"#{@trip_ticket2.customer_first_name}"}
      response.body.wont_include %Q{"customer_first_name":"#{@trip_ticket3.customer_first_name}"}
    end

    it "returns ticket status attribute" do
      @trip_ticket1.rescind!
      get "/api/v1/trip_tickets/sync", api_params(@provider)
      response.status.must_equal 200
      response.body.must_include %Q("status":"Rescinded")
      response.body.must_include %Q("rescinded":true)
    end

  end

  describe "GET /api/v1/trip_tickets/1" do
    include_examples "requires authenticatable params"

    it "should return the specified trip ticket as JSON" do
      get "/api/v1/trip_tickets/#{@trip_ticket1.id}", api_params(@provider, id: @trip_ticket1.id)
      response.status.must_equal 200
      response.body.must_include %Q{"customer_first_name":"#{@trip_ticket1.customer_first_name}"}
    end

    it "should not allow me to access a trip ticket originated by another provider" do
      get "/api/v1/trip_tickets/#{@trip_ticket3.id}", api_params(@provider, id: @trip_ticket3.id)
      response.status.must_equal 401
      response.body.wont_include %Q{"customer_first_name":"#{@trip_ticket3.customer_first_name}"}
    end
  end

  describe "PUT /api/v1/trip_tickets/1" do
    include_examples "requires authenticatable params"

    let(:trip_params) {{ trip_ticket: {
      customer_first_name: "Ariadne"
    }}}

    it "should update the specified trip ticket and return the trip ticket as JSON" do
      put "/api/v1/trip_tickets/#{@trip_ticket1.id}", api_params(@provider, trip_params.merge(id: @trip_ticket1.id))
      response.status.must_equal 200
      response.body.must_include %Q{"customer_first_name":"Ariadne"}
      @trip_ticket1.reload
      @trip_ticket1.customer_first_name.must_equal "Ariadne"
    end

    it "updates a nested location" do
      trip_params[:trip_ticket][:pick_up_location_attributes] = {
        address_1: '456 New Rd', city: 'Boston', state: 'MA', zip: '02134'
      }
      put "/api/v1/trip_tickets/#{@trip_ticket1.id}", api_params(@provider, trip_params.merge(id: @trip_ticket1.id))
      response.status.must_equal 200
      response.body.must_include %Q{"address_1":"456 New Rd"}
      @trip_ticket1.reload
      @trip_ticket1.pick_up_location.address_1.must_equal "456 New Rd"
    end

    it "updates a nested result" do
      FactoryGirl.create(:trip_claim, :trip_ticket => @trip_ticket1, :status => 'approved')
      trip_params[:trip_ticket][:trip_result_attributes] = { trip_ticket_id: @trip_ticket1.id, outcome: "Completed" }
      put "/api/v1/trip_tickets/#{@trip_ticket1.id}", api_params(@provider, trip_params.merge(id: @trip_ticket1.id))
      response.status.must_equal 200
      response.body.must_include %Q{"outcome":"Completed"}
      @trip_ticket1.reload
      @trip_ticket1.trip_result.wont_be_nil
      @trip_ticket1.trip_result.outcome.must_equal "Completed"
    end

    it "should not allow me to update a trip ticket originated by another provider" do
      put "/api/v1/trip_tickets/#{@trip_ticket3.id}", api_params(@provider, id: @trip_ticket3.id, trip_ticket: {customer_first_name: "Ariadne"})
      response.status.must_equal 401
      response.body.wont_include %Q{"customer_first_name":"Ariadne"}
    end

    it "supports simultaneously updating and rescinding a trip with param status=rescinded" do
      trip_params[:trip_ticket][:status] = 'rescinded'
      put "/api/v1/trip_tickets/#{@trip_ticket1.id}", api_params(@provider, trip_params.merge(id: @trip_ticket1.id))
      response.status.must_equal 200
      response.body.must_include %Q{"customer_first_name":"Ariadne"}
      response.body.must_include %Q{"rescinded":true}
    end

    it "supports simultaneously updating and rescinding a trip with param rescinded=true" do
      trip_params[:trip_ticket][:rescinded] = 'true'
      put "/api/v1/trip_tickets/#{@trip_ticket1.id}", api_params(@provider, trip_params.merge(id: @trip_ticket1.id))
      response.status.must_equal 200
      response.body.must_include %Q{"customer_first_name":"Ariadne"}
      response.body.must_include %Q{"rescinded":true}
    end
  end

  describe "POST /api/v1/trip_tickets" do
    include_examples "requires authenticatable params"

    let(:trip_params) {{ trip_ticket: {
      customer_information_withheld: false,
      customer_dob: "2012-01-01",
      customer_first_name: "First",
      customer_last_name: "Last",
      customer_primary_phone: "555-555-5555",
      customer_seats_required: 1,
      origin_customer_id: "newtrip123",
      requested_drop_off_time: "12:00",
      requested_pickup_time: "12:00",
      appointment_time: Time.zone.now,
      scheduling_priority: "pickup"
    }}}

    it "creates a trip ticket" do
      post "/api/v1/trip_tickets", api_params(@provider, trip_params)
      response.status.must_equal 201
      response.body.must_include %Q{"origin_customer_id":"newtrip123"}
    end

    it "creates a nested location" do
      trip_params[:trip_ticket][:pick_up_location_attributes] = {
        address_1: '456 New Rd', city: 'Boston', state: 'MA', zip: '02134'
      }
      post "/api/v1/trip_tickets", api_params(@provider, trip_params)
      response.status.must_equal 201
      response.body.must_include %Q{"address_1":"456 New Rd"}
    end
  end

  describe "PUT /api/v1/trip_tickets/1/rescind" do
    include_examples "requires authenticatable params"

    it "should rescind the specified trip ticket and return the trip ticket as JSON" do
      put "/api/v1/trip_tickets/#{@trip_ticket1.id}/rescind", api_params(@provider, id: @trip_ticket1.id)
      response.status.must_equal 200
      response.body.must_include %Q{"rescinded":true}
      @trip_ticket1.reload
      @trip_ticket1.rescinded.must_equal true
    end

    it "should not allow me to rescind a trip ticket originated by another provider" do
      put "/api/v1/trip_tickets/#{@trip_ticket3.id}/rescind", api_params(@provider, id: @trip_ticket3.id)
      response.status.must_equal 401
      response.body.wont_include %Q{"rescinded":true"}
    end
  end
end
