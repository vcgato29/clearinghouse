# Use this file to easily define all of your cron jobs.
# Learn more: http://github.com/javan/whenever

every '0 * * * 1-5', :roles => [:app] do
  rake 'clearinghouse:trip_tickets:expire'
end