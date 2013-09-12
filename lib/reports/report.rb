require 'reports/helpers'

module Reports
  extend ActiveSupport::Concern

  included do
    helper Reports::Helpers
  end

  class Report
    def initialize(report_class, user)
      raise "A valid user is required for generating reports" if user.blank?
      # this works because require isn't scoped
      require File.join("reports", "#{report_class}.rb")
      @report_class = "Reports::#{report_class.camelize}".constantize
      @report_instance = @report_class.new(user)
    end

    # TODO might be helpful if report headers and rows can be array of hashes so values can be sparse and in any order
    # e.g.:
    # headers returns [{ 'One Thing' => 'one_thing', 'Two Thing' => 'two_thing', 'Last Thing' => 'last_thing' }]
    # rows returns [{ 'last_thing' => '99', 'two_thing' => 2 }]
    # report outputs headers 'One Thing', 'Two Thing', 'Last Thing' and values "", "2", "99"

    # if a report has header rows, it should return an array of arrays
    def headers
      @report_instance.try(:headers) || []
    end

    # if a report has rows, it should return an array of arrays
    # subtotals and totals can be represented by returning a hash in the array as follows:
    # { 'subtotal' => [ 1, 2, 3, 4 ]}
    # { 'total' => [ 10, 20, 30, 40 ]}
    def rows
      @report_instance.try(:rows) || []
    end

    # a summary section is not displayed as a table, but is displayed like a form with labels and values in each row
    # reports should return summary data as a hash: { "A description" => "a value", "Another thing" => "thing value"  }
    def summary
      @report_instance.try(:summary)
    end
  end
end
