require 'reports/report'

module Reports
  class ProviderSummary < Report
    attr_accessor :summary

    def initialize(user, options = {})
      @report_user = user

      created_trips = @report_user.provider.trip_tickets.where(date_condition('trip_tickets.created_at', options))
      updated_trips = @report_user.provider.trip_tickets.where(date_condition('trip_tickets.updated_at', options))
      created_offers = @report_user.provider.trip_tickets.joins(:trip_claims).where(date_condition('trip_claims.created_at', options))
      updated_offers = @report_user.provider.trip_tickets.joins(:trip_claims).where(date_condition('trip_claims.updated_at', options))
      created_requests = @report_user.provider.trip_claims.where(date_condition('trip_claims.created_at', options))
      updated_requests = @report_user.provider.trip_claims.where(date_condition('trip_claims.updated_at', options))

      section_data = { "Total new trips" => created_trips.count }
      create_summary_section("New Trip Tickets", section_data)

      section_data = { "Total updated trips" => updated_trips.count }
      updated_trips.each do |trip|
        status = trip.simple_originator_status(user.provider)
        section_data[status] ||= 0
        section_data[status] += 1
      end
      create_summary_section("Updated Trip Tickets", section_data)

      section_data = { "Total new offers" => created_offers.count }
      create_summary_section("New Claim Offers Received", section_data)

      section_data = { "Total updated offers" => updated_offers.count }
      updated_offers.each do |claim|
        status = claim.status.capitalize
        section_data[status] ||= 0
        section_data[status] += 1
      end
      create_summary_section("Updated Claim Offers Received", section_data)

      section_data = { "Total new requests" => created_requests.count }
      create_summary_section("New Claim Requests Submitted", section_data)

      section_data = { "Total updated requests" => updated_requests.count }
      updated_requests.each do |claim|
        status = claim.status.capitalize
        section_data[status] ||= 0
        section_data[status] += 1
      end
      create_summary_section("Updated Claim Requests Submitted", section_data)
    end
  end
end