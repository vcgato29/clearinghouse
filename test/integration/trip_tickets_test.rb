require 'test_helper'

class TripTicketsTest < ActionController::IntegrationTest

  include Warden::Test::Helpers
  Warden.test_mode!
  
  setup do
    @provider = FactoryGirl.create(:provider, :name => "Microsoft")
    @password = "password 1"

    @user = FactoryGirl.create(:user, 
      :password => @password, 
      :password_confirmation => @password, 
      :provider => @provider)
    @user.roles = [Role.find_or_create_by_name!("provider_admin")]
    @user.save!

    login_as @user, :scope => :user
    visit '/'
  end

  teardown do
    # For selectively enabling selenium driven tests
    # Capybara.current_driver = nil # reset
  end
  
  test "provider admins can create new trip tickets" do
    click_link "Trip Tickets"
    click_link "New Trip ticket"
    
    fill_in_minimum_required_trip_ticket_fields

    fill_in "Ethnicity", :with => "Not of Hispanic Origin"
    fill_in "Race", :with => "Asian"
    fill_in "Trip Purpose", :with => "Some information"
    
    click_button "Create Trip ticket"
    
    assert page.has_content?("Trip ticket was successfully created")
  end

 
  TripTicket::ARRAY_FIELD_NAMES.each do |field_sym|
    describe "#{field_sym.to_s} string_array fields" do
      test "provider admins should see a single #{field_sym.to_s} field when creating a trip ticket (and can save it even w/o javascript, but cannot add more than a single new value)" do
        click_link "Trip Tickets"
        click_link "New Trip ticket"
      
        fill_in_minimum_required_trip_ticket_fields
      
        within("##{field_sym.to_s}") do
          assert_equal 1, all('.pgStringArrayValue').size
          all('.pgStringArrayValue')[0].set('A')
        end      
      
        click_button "Create Trip ticket"

        assert page.has_content?("Trip ticket was successfully created")

        within("##{field_sym.to_s}") do
          assert_equal 2, all('.pgStringArrayValue').size # "A" + blank      
          assert page.has_selector?('.pgStringArrayValue[value=\'A\']')
        end
      end

      test "provider admins should see #{field_sym.to_s} fields when editing a trip ticket (and can modify the current values without javascript, but cannot add more than a single new value)" do
        # NOTE users can modify the current values without javascript, but cannot add more than a single new value

        trip_ticket = FactoryGirl.create(:trip_ticket, :originator => @provider)
        trip_ticket.send("#{field_sym.to_s}=".to_sym, ['A', 'B'])
        trip_ticket.save!

        visit "/trip_tickets/#{trip_ticket.id}"

        within("##{field_sym.to_s}") do
          # NOTE - we cannot predict the order of these hstore attributes
          assert page.has_selector?('.pgStringArrayValue[value=\'A\']')
          assert page.has_selector?('.pgStringArrayValue[value=\'B\']')

          find('.pgStringArrayValue[value=\'\']').set('C')
          find('.pgStringArrayValue[value=\'B\']').set('')
        end

        click_button "Update Trip ticket"

        assert page.has_content?("Trip ticket was successfully updated")

        within("##{field_sym.to_s}") do
          # PROTIP - If this fails, update the TripTicketsController#compact_string_array_params method
          assert_equal 3, all('.pgStringArrayValue').size # "A" + "B" + blank
          
          assert page.has_selector?('.pgStringArrayValue[value=\'A\']')
          assert page.has_selector?('.pgStringArrayValue[value=\'C\']')
          assert page.has_no_selector?('.pgStringArrayValue[value=\'B\']')
        end
      end

      test "users who cannot edit an existing trip ticket should see an unordered list of #{field_sym.to_s}" do
        provider_2 = FactoryGirl.create(:provider)
        relationship = ProviderRelationship.create!(
          :requesting_provider => @provider,
          :cooperating_provider => provider_2
        )
        relationship.approve!
        trip_ticket = FactoryGirl.create(:trip_ticket, :originator => provider_2)
        trip_ticket.send("#{field_sym.to_s}=".to_sym, ['A', 'B'])
        trip_ticket.save!

        visit "/trip_tickets/#{trip_ticket.id}"

        within("##{field_sym.to_s}") do
          # NOTE - we cannot predict the order of these hstore attributes
          assert page.has_no_selector?('.pgStringArrayValue[value=\'A\']')
          assert page.has_no_selector?('.pgStringArrayValue[value=\'B\']')

          assert page.has_selector?('li', :text => "A")
          assert page.has_selector?('li', :text => "B")
        end
      end
    end
  end
    
  describe "customer_identifiers hstore fields" do
    # test "provider admins can add customer identifier attributes to a new trip ticket (using javascript)" do
    #   skip "Having trouble getting user logins to work with selenium - cdb 2013-01-29"
    #   
    #   Capybara.current_driver = :selenium
    # 
    #   visit '/'
    #   fill_in 'Email', :with => @user.email
    #   fill_in 'Password', :with => @password
    #   click_button 'Sign in'
    #   
    #   # vv- here be unexercised tests -vv
    #   
    #   click_link "Trip Tickets"
    #   click_link "New Trip ticket"
    #
    #   fill_in_minimum_required_trip_ticket_fields
    #   
    #   assert_equal 1, all('.hstoreAttributeName').size
    #   assert_equal 1, all('.hstoreAttributeValue').size
    #   click_link "Add Customer Identifier"
    #   assert_equal 2, all('.hstoreAttributeName').size
    #   assert_equal 2, all('.hstoreAttributeValue').size
    #   
    #   all('.hstoreAttributeName')[0].set('Some')
    #   all('.hstoreAttributeValue')[0].set('Thing')
    #   all('.hstoreAttributeName')[1].set('Other')
    #   all('.hstoreAttributeValue')[1].set('Thang')
    #   
    #   click_button "Create Trip ticket"
    #   
    #   assert page.has_content?("Trip ticket was successfully created")
    #   
    #   # NOTE - we cannot predict the order of these hstore attributes
    #   assert page.has_selector?('.hstoreAttributeName[value=\'some\']')
    #   assert page.has_selector?('.hstoreAttributeValue[value=\'Thing\']')
    #   assert page.has_selector?('.hstoreAttributeName[value=\'other\']')
    #   assert page.has_selector?('.hstoreAttributeValue[value=\'Thang\']')
    # end
    
    test "provider admins should see a single pair of customer identifier attribute fields when creating a trip ticket (but cannot save them without javascript)" do
      click_link "Trip Tickets"
      click_link "New Trip ticket"
      
      within('#customer_identifiers') do
        assert_equal 1, all('.hstoreAttributeName').size
        assert_equal 1, all('.hstoreAttributeValue').size
      end      
    end

    test "provider admins should see pairs of customer identifier attribute fields when editing a trip ticket (but cannot modify the current keys or add new pairs without javascript)" do
      trip_ticket = FactoryGirl.create(:trip_ticket, :originator => @provider)
      trip_ticket.customer_identifiers = {:charlie => 'Brown', :solid => 'Gold'}
      trip_ticket.save!

      visit "/trip_tickets/#{trip_ticket.id}"
      
      within('#customer_identifiers') do
        # NOTE - we cannot predict the order of these hstore attributes
        assert page.has_selector?('.hstoreAttributeName[value=\'charlie\']')
        assert page.has_selector?('.hstoreAttributeValue[value=\'Brown\']')
        assert page.has_selector?('.hstoreAttributeName[value=\'solid\']')
        assert page.has_selector?('.hstoreAttributeValue[value=\'Gold\']')
        
        all('.hstoreAttributeValue')[0].set('Chaplin')
        all('.hstoreAttributeValue')[1].set('Waste')
      end
      
      click_button "Update Trip ticket"
      
      assert page.has_content?("Trip ticket was successfully updated")
      
      # NOTE - we cannot predict the order of these hstore attributes
      assert page.has_selector?('.hstoreAttributeValue[value=\'Chaplin\']')
      assert page.has_selector?('.hstoreAttributeValue[value=\'Waste\']')
    end

    test "users who cannot edit an existing trip ticket should see an unordered list of customer identifier attribute pairs" do
      provider_2 = FactoryGirl.create(:provider)
      relationship = ProviderRelationship.create!(
        :requesting_provider => @provider,
        :cooperating_provider => provider_2
      )
      relationship.approve!
      trip_ticket = FactoryGirl.create(:trip_ticket, :originator => provider_2)
      trip_ticket.customer_identifiers = {:charlie => 'Brown', :solid => 'Gold'}
      trip_ticket.save!

      visit "/trip_tickets/#{trip_ticket.id}"
      
      within('#customer_identifiers') do
        # NOTE - we cannot predict the order of these hstore attributes
        assert page.has_no_selector?('.hstoreAttributeName[value=\'charlie\']')
        assert page.has_no_selector?('.hstoreAttributeValue[value=\'Brown\']')
        assert page.has_no_selector?('.hstoreAttributeName[value=\'solid\']')
        assert page.has_no_selector?('.hstoreAttributeValue[value=\'Gold\']')
        
        assert page.has_selector?('li', :text => "charlie: Brown")
        assert page.has_selector?('li', :text => "solid: Gold")
      end
    end
  end
  
  describe "filtering" do
    describe "clear filters" do
      setup do
        @u1 = FactoryGirl.create(:trip_ticket, :customer_last_name => 'Jim', :originator => @provider)
      end
    
      it "provides a link to clear the search results" do
        visit "/trip_tickets"
      
        within('#trip_ticket_filters') do
          fill_in "Customer Name", :with => 'BOB'
          click_button "Search"
        end
        
        assert page.has_no_link?("", {:href => trip_ticket_path(@u1)})
        
        within('#trip_ticket_filters') do
          assert page.has_link?("Clear All Filters")
          click_link "Clear All Filters"
        end
        
        assert page.has_link?("", {:href => trip_ticket_path(@u1)})
      end
    end
    
    describe "customer name filter" do
      setup do
        @u1 = FactoryGirl.create(:trip_ticket, :customer_first_name  => 'Bob', :originator => @provider)
        @u2 = FactoryGirl.create(:trip_ticket, :customer_middle_name => 'Bob', :originator => @provider)
        @u3 = FactoryGirl.create(:trip_ticket, :customer_last_name   => 'Bob', :originator => @provider)
        @u4 = FactoryGirl.create(:trip_ticket, :customer_last_name   => 'Jim', :originator => @provider)
        @u5 = FactoryGirl.create(:trip_ticket, :customer_first_name  => 'Bob')
      end
    
      it "returns trip tickets accessible by the current user with a matching first, middle, or last customer name" do
        visit "/trip_tickets"
      
        within('#trip_ticket_filters') do
          fill_in "Customer Name", :with => 'BOB'
          click_button "Search"
        end

        assert page.has_link?("", {:href => trip_ticket_path(@u1)})
        assert page.has_link?("", {:href => trip_ticket_path(@u2)})
        assert page.has_link?("", {:href => trip_ticket_path(@u3)})
        assert page.has_no_link?("", {:href => trip_ticket_path(@u4)})
        assert page.has_no_link?("", {:href => trip_ticket_path(@u5)})
      end
    end
    
    describe "customer address or phone filter" do
      setup do
        @l1 = FactoryGirl.create(:trip_ticket, :originator => @provider, :customer_address => FactoryGirl.create(:location, :address_1 => "Oak Street", :address_2 => ""))
        @l2 = FactoryGirl.create(:trip_ticket, :originator => @provider, :customer_address => FactoryGirl.create(:location, :address_1 => "Some Street", :address_2 => "Oak Suite"))
        @l3 = FactoryGirl.create(:trip_ticket, :originator => @provider, :customer_address => FactoryGirl.create(:location, :address_1 => "Some Street", :address_2 => ""), :pick_up_location => FactoryGirl.create(:location, :address_1 => "Oak Street"))
        @l4 = FactoryGirl.create(:trip_ticket,                           :customer_address => FactoryGirl.create(:location, :address_1 => "Oak Street",  :address_2 => ""))
        @l5 = FactoryGirl.create(:trip_ticket, :originator => @provider, :customer_primary_phone => "800-555-soak")   # <- contrived, I know
        @l6 = FactoryGirl.create(:trip_ticket, :originator => @provider, :customer_emergency_phone => "555-oak-1234") # <- contrived, I know
      end
    
      it "returns trip tickets accessible by the current user with a matching customer street address or phone numbers" do
        visit "/trip_tickets"
      
        within('#trip_ticket_filters') do
          fill_in "Customer Address or Phone", :with => 'OAK'
          click_button "Search"
        end

        assert page.has_link?("", {:href => trip_ticket_path(@l1)})
        assert page.has_link?("", {:href => trip_ticket_path(@l2)})
        assert page.has_link?("", {:href => trip_ticket_path(@l5)})
        assert page.has_link?("", {:href => trip_ticket_path(@l6)})
        assert page.has_no_link?("", {:href => trip_ticket_path(@l3)})
        assert page.has_no_link?("", {:href => trip_ticket_path(@l4)})
      end
    end
    
    describe "pick up location filter" do
      setup do
        @l1 = FactoryGirl.create(:trip_ticket, :originator => @provider, :pick_up_location => FactoryGirl.create(:location, :address_1 => "Oak Street", :address_2 => ""))
        @l2 = FactoryGirl.create(:trip_ticket, :originator => @provider, :pick_up_location => FactoryGirl.create(:location, :address_1 => "Some Street", :address_2 => "Oak Suite"))
        @l3 = FactoryGirl.create(:trip_ticket, :originator => @provider, :pick_up_location => FactoryGirl.create(:location, :address_1 => "Some Street", :address_2 => ""), :customer_address => FactoryGirl.create(:location, :address_1 => "Oak Street"))
        @l4 = FactoryGirl.create(:trip_ticket,                           :pick_up_location => FactoryGirl.create(:location, :address_1 => "Oak Street",  :address_2 => ""))
      end
    
      it "returns trip tickets accessible by the current user with a matching pick up location address" do
        visit "/trip_tickets"
      
        within('#trip_ticket_filters') do
          fill_in "Pickup Address", :with => 'OAK'
          click_button "Search"
        end

        assert page.has_link?("", {:href => trip_ticket_path(@l1)})
        assert page.has_link?("", {:href => trip_ticket_path(@l2)})
        assert page.has_no_link?("", {:href => trip_ticket_path(@l3)})
        assert page.has_no_link?("", {:href => trip_ticket_path(@l4)})
      end
    end
    
    describe "drop off location filter" do
      setup do
        @l1 = FactoryGirl.create(:trip_ticket, :originator => @provider, :drop_off_location => FactoryGirl.create(:location, :address_1 => "Oak Street", :address_2 => ""))
        @l2 = FactoryGirl.create(:trip_ticket, :originator => @provider, :drop_off_location => FactoryGirl.create(:location, :address_1 => "Some Street", :address_2 => "Oak Suite"))
        @l3 = FactoryGirl.create(:trip_ticket, :originator => @provider, :drop_off_location => FactoryGirl.create(:location, :address_1 => "Some Street", :address_2 => ""), :customer_address => FactoryGirl.create(:location, :address_1 => "Oak Street"))
        @l4 = FactoryGirl.create(:trip_ticket,                           :drop_off_location => FactoryGirl.create(:location, :address_1 => "Oak Street",  :address_2 => ""))
      end
    
      it "returns trip tickets accessible by the current user with a matching drop off location address" do
        visit "/trip_tickets"
      
        within('#trip_ticket_filters') do
          fill_in "Dropoff Address", :with => 'OAK'
          click_button "Search"
        end

        assert page.has_link?("", {:href => trip_ticket_path(@l1)})
        assert page.has_link?("", {:href => trip_ticket_path(@l2)})
        assert page.has_no_link?("", {:href => trip_ticket_path(@l3)})
        assert page.has_no_link?("", {:href => trip_ticket_path(@l4)})
      end
    end
    
    describe "originating provider filter" do
      setup do
        @provider_2 = FactoryGirl.create(:provider, :name => "Google")
        relationship = ProviderRelationship.create!(
          :requesting_provider => @provider,
          :cooperating_provider => @provider_2
        )
        relationship.approve!
        @provider_3 = FactoryGirl.create(:provider, :name => "Yahoo")
        relationship = ProviderRelationship.create!(
          :requesting_provider => @provider,
          :cooperating_provider => @provider_3
        )
        relationship.approve!
        @t1 = FactoryGirl.create(:trip_ticket, :originator => @provider)
        @t2 = FactoryGirl.create(:trip_ticket, :originator => @provider_2)
        @t3 = FactoryGirl.create(:trip_ticket, :originator => @provider_3)
        @t4 = FactoryGirl.create(:trip_ticket)
      end
    
      it "returns trip tickets accessible by the current user with matching originating providers" do
        visit "/trip_tickets"
      
        within('#trip_ticket_filters') do
          select "Microsoft", :from => "Originating Provider"
          select "Google", :from => "Originating Provider"
          click_button "Search"
        end
        
        assert page.has_link?("", {:href => trip_ticket_path(@t1)})
        assert page.has_link?("", {:href => trip_ticket_path(@t2)})
        assert page.has_no_link?("", {:href => trip_ticket_path(@t3)})
        assert page.has_no_link?("", {:href => trip_ticket_path(@t4)})
      end
    end
    
    describe "claiming provider filter" do
      setup do
        @provider_2 = FactoryGirl.create(:provider, :name => "Google")
        relationship = ProviderRelationship.create!(
          :requesting_provider => @provider,
          :cooperating_provider => @provider_2
        )
        relationship.approve!
        @provider_3 = FactoryGirl.create(:provider, :name => "Yahoo")
        relationship = ProviderRelationship.create!(
          :requesting_provider => @provider,
          :cooperating_provider => @provider_3
        )
        relationship.approve!
        
        @t1 = FactoryGirl.create(:trip_ticket, :originator => @provider)
        FactoryGirl.create(:trip_claim, :trip_ticket => @t1, :claimant => @provider_2)
        
        @t2 = FactoryGirl.create(:trip_ticket, :originator => @provider_2)
        FactoryGirl.create(:trip_claim, :trip_ticket => @t2, :claimant => @provider_3)
        
        @t3 = FactoryGirl.create(:trip_ticket, :originator => @provider)
        FactoryGirl.create(:trip_claim, :trip_ticket => @t3)
        
        @t4 = FactoryGirl.create(:trip_ticket)
        FactoryGirl.create(:trip_claim, :trip_ticket => @t4, :claimant => @provider)
      end
    
      it "returns trip tickets accessible by the current user with matching claiming providers" do
        visit "/trip_tickets"
      
        within('#trip_ticket_filters') do
          select "Microsoft", :from => "Claiming Provider"
          select "Google", :from => "Claiming Provider"
          click_button "Search"
        end
        
        assert page.has_link?("", {:href => trip_ticket_path(@t1)})
        assert page.has_no_link?("", {:href => trip_ticket_path(@t2)})
        assert page.has_no_link?("", {:href => trip_ticket_path(@t3)})
        assert page.has_no_link?("", {:href => trip_ticket_path(@t4)})
      end
    end
    
    describe "trip ticket status filter" do
      before do
        # unclaimed
        @t1_1 = FactoryGirl.create(:trip_ticket, :originator => @provider)
        @t1_2 = FactoryGirl.create(:trip_ticket)

        # one claim, not approved
        @t2_1 = FactoryGirl.create(:trip_ticket, :originator => @provider)
        FactoryGirl.create(:trip_claim, :status => TripClaim::STATUS[:pending], :trip_ticket => @t2_1)
        
        @t2_2 = FactoryGirl.create(:trip_ticket)
        FactoryGirl.create(:trip_claim, :status => TripClaim::STATUS[:pending], :trip_ticket => @t2_2)
        
        @t3_1 = FactoryGirl.create(:trip_ticket, :originator => @provider)
        FactoryGirl.create(:trip_claim, :status => TripClaim::STATUS[:declined], :trip_ticket => @t3_1)

        @t3_2 = FactoryGirl.create(:trip_ticket)
        FactoryGirl.create(:trip_claim, :status => TripClaim::STATUS[:declined], :trip_ticket => @t3_2)

        # multiple claims, none approved
        @t4_1 = FactoryGirl.create(:trip_ticket, :originator => @provider)
        FactoryGirl.create(:trip_claim, :status => TripClaim::STATUS[:pending],  :trip_ticket => @t4_1)
        FactoryGirl.create(:trip_claim, :status => TripClaim::STATUS[:declined], :trip_ticket => @t4_1)

        @t4_2 = FactoryGirl.create(:trip_ticket)
        FactoryGirl.create(:trip_claim, :status => TripClaim::STATUS[:pending],  :trip_ticket => @t4_2)
        FactoryGirl.create(:trip_claim, :status => TripClaim::STATUS[:declined], :trip_ticket => @t4_2)

        # multiple claims, one approved
        @t5_1 = FactoryGirl.create(:trip_ticket, :originator => @provider)
        FactoryGirl.create(:trip_claim, :status => TripClaim::STATUS[:pending],  :trip_ticket => @t5_1)
        FactoryGirl.create(:trip_claim, :status => TripClaim::STATUS[:declined], :trip_ticket => @t5_1)
        FactoryGirl.create(:trip_claim, :status => TripClaim::STATUS[:pending],  :trip_ticket => @t5_1).approve!

        @t5_2 = FactoryGirl.create(:trip_ticket)
        FactoryGirl.create(:trip_claim, :status => TripClaim::STATUS[:pending],  :trip_ticket => @t5_2)
        FactoryGirl.create(:trip_claim, :status => TripClaim::STATUS[:declined], :trip_ticket => @t5_2)
        FactoryGirl.create(:trip_claim, :status => TripClaim::STATUS[:pending],  :trip_ticket => @t5_2).approve!

        # one claim, approved
        @t6_1 = FactoryGirl.create(:trip_ticket, :originator => @provider)
        FactoryGirl.create(:trip_claim, :status => TripClaim::STATUS[:pending], :trip_ticket => @t6_1).approve!

        @t6_2 = FactoryGirl.create(:trip_ticket)
        FactoryGirl.create(:trip_claim, :status => TripClaim::STATUS[:pending], :trip_ticket => @t6_2).approve!
      end
      
      it "returns trip tickets accessible by the current user which have approved claims" do
        visit "/trip_tickets"
      
        within('#trip_ticket_filters') do
          select "approved", :from => "Claim Status"
          click_button "Search"
        end
        
        assert page.has_no_link?("", {:href => trip_ticket_path(@t1_1)})
        assert page.has_no_link?("", {:href => trip_ticket_path(@t1_2)})
        assert page.has_no_link?("", {:href => trip_ticket_path(@t2_1)})
        assert page.has_no_link?("", {:href => trip_ticket_path(@t2_2)})
        assert page.has_no_link?("", {:href => trip_ticket_path(@t3_1)})
        assert page.has_no_link?("", {:href => trip_ticket_path(@t3_2)})
        assert page.has_no_link?("", {:href => trip_ticket_path(@t4_1)})
        assert page.has_no_link?("", {:href => trip_ticket_path(@t4_2)})
        assert page.has_link?("",    {:href => trip_ticket_path(@t5_1)})
        assert page.has_no_link?("", {:href => trip_ticket_path(@t5_2)})
        assert page.has_link?("",    {:href => trip_ticket_path(@t6_1)})
        assert page.has_no_link?("", {:href => trip_ticket_path(@t6_2)})
      end
      
      it "returns trip tickets accessible by the current user which have pending claims" do
        visit "/trip_tickets"
      
        within('#trip_ticket_filters') do
          select "pending", :from => "Claim Status"
          click_button "Search"
        end        
        
        assert page.has_no_link?("", {:href => trip_ticket_path(@t1_1)})
        assert page.has_no_link?("", {:href => trip_ticket_path(@t1_2)})
        assert page.has_link?("",    {:href => trip_ticket_path(@t2_1)})
        assert page.has_no_link?("", {:href => trip_ticket_path(@t2_2)})
        assert page.has_no_link?("", {:href => trip_ticket_path(@t3_1)})
        assert page.has_no_link?("", {:href => trip_ticket_path(@t3_2)})
        assert page.has_link?("",    {:href => trip_ticket_path(@t4_1)})
        assert page.has_no_link?("", {:href => trip_ticket_path(@t4_2)})
        assert page.has_no_link?("", {:href => trip_ticket_path(@t5_1)})
        assert page.has_no_link?("", {:href => trip_ticket_path(@t5_2)})
        assert page.has_no_link?("", {:href => trip_ticket_path(@t6_1)})
        assert page.has_no_link?("", {:href => trip_ticket_path(@t6_2)})
      end
      
      it "returns trip tickets accessible by the current user which have no claims on them or which have only declined claims" do
        visit "/trip_tickets"
      
        within('#trip_ticket_filters') do
          select "unclaimed", :from => "Claim Status"
          click_button "Search"
        end
        
        assert page.has_link?("",    {:href => trip_ticket_path(@t1_1)})
        assert page.has_no_link?("", {:href => trip_ticket_path(@t1_2)})
        assert page.has_no_link?("", {:href => trip_ticket_path(@t2_1)})
        assert page.has_no_link?("", {:href => trip_ticket_path(@t2_2)})
        assert page.has_link?("",    {:href => trip_ticket_path(@t3_1)})
        assert page.has_no_link?("", {:href => trip_ticket_path(@t3_2)})
        assert page.has_no_link?("", {:href => trip_ticket_path(@t4_1)})
        assert page.has_no_link?("", {:href => trip_ticket_path(@t4_2)})
        assert page.has_no_link?("", {:href => trip_ticket_path(@t5_1)})
        assert page.has_no_link?("", {:href => trip_ticket_path(@t5_2)})
        assert page.has_no_link?("", {:href => trip_ticket_path(@t6_1)})
        assert page.has_no_link?("", {:href => trip_ticket_path(@t6_2)})
      end
    end
    
    describe "trip ticket seats required filter" do
      before do
        @t01 = FactoryGirl.create(:trip_ticket, :num_attendants => 0, :customer_seats_required => 0, :num_guests => 0, :originator => @provider)
        @t02 = FactoryGirl.create(:trip_ticket, :num_attendants => 2, :customer_seats_required => 2, :num_guests => 2, :originator => @provider)
        @t03 = FactoryGirl.create(:trip_ticket, :num_attendants => 6, :customer_seats_required => 2, :num_guests => 2, :originator => @provider)
        @t04 = FactoryGirl.create(:trip_ticket, :num_attendants => 6, :customer_seats_required => 0, :num_guests => 0, :originator => @provider)
        @t05 = FactoryGirl.create(:trip_ticket, :num_attendants => 0, :customer_seats_required => 6, :num_guests => 0, :originator => @provider)
        @t06 = FactoryGirl.create(:trip_ticket, :num_attendants => 0, :customer_seats_required => 0, :num_guests => 6, :originator => @provider)
        @t07 = FactoryGirl.create(:trip_ticket, :num_attendants => 0, :customer_seats_required => 0, :num_guests => 8, :originator => @provider)
        @t08 = FactoryGirl.create(:trip_ticket, :num_attendants => 1, :customer_seats_required => 1, :num_guests => 1, :originator => @provider)

        @t09 = FactoryGirl.create(:trip_ticket, :num_attendants => 2, :customer_seats_required => 2, :num_guests => 2)
        @t10 = FactoryGirl.create(:trip_ticket, :num_attendants => 6, :customer_seats_required => 0, :num_guests => 0)
      end
      
      it "returns trip tickets accessible by the current user that have no claims on them" do
        visit "/trip_tickets"
      
        within('#trip_ticket_filters') do
          fill_in "trip_ticket_filters_seats_required_min", :with => "3"
          fill_in "trip_ticket_filters_seats_required_max", :with => "6"
          click_button "Search"
        end
        
        assert page.has_no_link?("", {:href => trip_ticket_path(@t01)})
        assert page.has_link?("",    {:href => trip_ticket_path(@t02)})
        assert page.has_no_link?("", {:href => trip_ticket_path(@t03)})
        assert page.has_link?("",    {:href => trip_ticket_path(@t04)})
        assert page.has_link?("",    {:href => trip_ticket_path(@t05)})
        assert page.has_link?("",    {:href => trip_ticket_path(@t06)})
        assert page.has_no_link?("", {:href => trip_ticket_path(@t07)})
        assert page.has_link?("",    {:href => trip_ticket_path(@t08)})
        assert page.has_no_link?("", {:href => trip_ticket_path(@t09)})
        assert page.has_no_link?("", {:href => trip_ticket_path(@t10)})

        within('#trip_ticket_filters') do
          fill_in "trip_ticket_filters_seats_required_min", :with => "3"
          fill_in "trip_ticket_filters_seats_required_max", :with => "0"
          click_button "Search"
        end
        
        assert page.has_link?("",    {:href => trip_ticket_path(@t01)})
        assert page.has_no_link?("", {:href => trip_ticket_path(@t02)})
        assert page.has_no_link?("", {:href => trip_ticket_path(@t03)})
        assert page.has_no_link?("", {:href => trip_ticket_path(@t04)})
        assert page.has_no_link?("", {:href => trip_ticket_path(@t05)})
        assert page.has_no_link?("", {:href => trip_ticket_path(@t06)})
        assert page.has_no_link?("", {:href => trip_ticket_path(@t07)})
        assert page.has_link?("",    {:href => trip_ticket_path(@t08)})
        assert page.has_no_link?("", {:href => trip_ticket_path(@t09)})
        assert page.has_no_link?("", {:href => trip_ticket_path(@t10)})
      end      
    end

    describe "scheduling priority filter" do
      setup do
        @t1 = FactoryGirl.create(:trip_ticket, :scheduling_priority => 'dropoff', :originator => @provider)
        @t2 = FactoryGirl.create(:trip_ticket, :scheduling_priority => 'pickup',  :originator => @provider)
        @t3 = FactoryGirl.create(:trip_ticket, :scheduling_priority => 'dropoff')
        @t4 = FactoryGirl.create(:trip_ticket, :scheduling_priority => 'pickup')
      end
    
      it "returns trip tickets accessible by the current user with a matching scheduling priority" do
        visit "/trip_tickets"
      
        within('#trip_ticket_filters') do
          select "Drop-off", :from => 'Scheduling Priority'
          click_button "Search"
        end

        assert page.has_link?("",    {:href => trip_ticket_path(@t1)})
        assert page.has_no_link?("", {:href => trip_ticket_path(@t2)})
        assert page.has_no_link?("", {:href => trip_ticket_path(@t3)})
        assert page.has_no_link?("", {:href => trip_ticket_path(@t4)})
      
        within('#trip_ticket_filters') do
          select "Pickup", :from => 'Scheduling Priority'
          click_button "Search"
        end

        assert page.has_no_link?("", {:href => trip_ticket_path(@t1)})
        assert page.has_link?("",    {:href => trip_ticket_path(@t2)})
        assert page.has_no_link?("", {:href => trip_ticket_path(@t3)})
        assert page.has_no_link?("", {:href => trip_ticket_path(@t4)})
      end
    end

    describe "trip time filter" do
      setup do
        @t1 = FactoryGirl.create(:trip_ticket, :originator => @provider, :appointment_time => Time.zone.parse('2012-01-01'), :requested_pickup_time => Time.zone.parse('11:00'), :requested_drop_off_time => Time.zone.parse('22:00'))
        @t2 = FactoryGirl.create(:trip_ticket, :originator => @provider, :appointment_time => Time.zone.parse('2012-01-01'), :requested_pickup_time => Time.zone.parse('10:00'), :requested_drop_off_time => Time.zone.parse('23:00'))
        @t3 = FactoryGirl.create(:trip_ticket, :originator => @provider, :appointment_time => Time.zone.parse('2012-03-01'), :requested_pickup_time => Time.zone.parse('11:00'), :requested_drop_off_time => Time.zone.parse('22:00'))
        @t4 = FactoryGirl.create(:trip_ticket,                           :appointment_time => Time.zone.parse('2012-04-01'), :requested_pickup_time => Time.zone.parse('11:00'), :requested_drop_off_time => Time.zone.parse('22:00'))
      end
    
      it "returns trip tickets accessible by the current user with a requested_pickup_time or requested_drop_off_time between the selected times" do
        visit "/trip_tickets"
      
        within('#trip_ticket_filters') do
          select "2012", :from => 'trip_ticket_filters_trip_time_start_year'
          select "January", :from => 'trip_ticket_filters_trip_time_start_month'
          select "1", :from => 'trip_ticket_filters_trip_time_start_day'
          select "11 AM", :from => 'trip_ticket_filters_trip_time_start_hour'
          select "", :from => 'trip_ticket_filters_trip_time_start_minute'

          select "2012", :from => 'trip_ticket_filters_trip_time_end_year'
          select "January", :from => 'trip_ticket_filters_trip_time_end_month'
          select "1", :from => 'trip_ticket_filters_trip_time_end_day'
          select "10 PM", :from => 'trip_ticket_filters_trip_time_end_hour'
          select "", :from => 'trip_ticket_filters_trip_time_end_minute'
          click_button "Search"
        end

        assert page.has_link?("",    {:href => trip_ticket_path(@t1)})
        assert page.has_no_link?("", {:href => trip_ticket_path(@t2)})
        assert page.has_no_link?("", {:href => trip_ticket_path(@t3)})
        assert page.has_no_link?("", {:href => trip_ticket_path(@t4)})
        
        within('#trip_ticket_filters') do
          select "2012", :from => 'trip_ticket_filters_trip_time_start_year'
          select "February", :from => 'trip_ticket_filters_trip_time_start_month'
          select "1", :from => 'trip_ticket_filters_trip_time_start_day'
          select "12 PM", :from => 'trip_ticket_filters_trip_time_start_hour'
          select "", :from => 'trip_ticket_filters_trip_time_start_minute'

          select "2012", :from => 'trip_ticket_filters_trip_time_end_year'
          select "March", :from => 'trip_ticket_filters_trip_time_end_month'
          select "1", :from => 'trip_ticket_filters_trip_time_end_day'
          select "09 PM", :from => 'trip_ticket_filters_trip_time_end_hour'
          select "", :from => 'trip_ticket_filters_trip_time_end_minute'
          click_button "Search"
        end

        assert page.has_no_link?("", {:href => trip_ticket_path(@t1)})
        assert page.has_no_link?("", {:href => trip_ticket_path(@t2)})
        assert page.has_link?("",    {:href => trip_ticket_path(@t3)})
        assert page.has_no_link?("", {:href => trip_ticket_path(@t4)})
      end
    end

    describe "customer identifiers filter" do
      setup do
        @t01 = FactoryGirl.create(:trip_ticket, :customer_identifiers                 => {'a' => 'b', 'c' => 'd'}, :originator => @provider)
        @t02 = FactoryGirl.create(:trip_ticket, :customer_mobility_impairments        => ['a', 'b'], :originator => @provider)
        @t03 = FactoryGirl.create(:trip_ticket, :customer_mobility_impairments        => ['b', 'c'])
        @t04 = FactoryGirl.create(:trip_ticket, :customer_eligibility_factors         => ['c', 'a'], :originator => @provider)
        @t05 = FactoryGirl.create(:trip_ticket, :customer_eligibility_factors         => ['a', 'b'])
        @t06 = FactoryGirl.create(:trip_ticket, :customer_assistive_devices           => ['b', 'c'], :originator => @provider)
        @t07 = FactoryGirl.create(:trip_ticket, :customer_assistive_devices           => ['c', 'a'])
        @t08 = FactoryGirl.create(:trip_ticket, :customer_service_animals             => ['a', 'b'], :originator => @provider)
        @t09 = FactoryGirl.create(:trip_ticket, :customer_service_animals             => ['b', 'c'])
        @t10 = FactoryGirl.create(:trip_ticket, :guest_or_attendant_service_animals   => ['c', 'a'], :originator => @provider)
        @t11 = FactoryGirl.create(:trip_ticket, :guest_or_attendant_service_animals   => ['a', 'b'])
        @t12 = FactoryGirl.create(:trip_ticket, :guest_or_attendant_assistive_devices => ['b', 'c'], :originator => @provider)
        @t13 = FactoryGirl.create(:trip_ticket, :guest_or_attendant_assistive_devices => ['c', 'a'])
        @t14 = FactoryGirl.create(:trip_ticket, :trip_funders                         => ['a', 'b'], :originator => @provider)
        @t15 = FactoryGirl.create(:trip_ticket, :trip_funders                         => ['b', 'c'])
      end
    
      it "returns trip tickets accessible by the current user with a matching scheduling priority" do
        visit "/trip_tickets"
      
        within('#trip_ticket_filters') do
          fill_in "trip_ticket_filters_customer_identifiers", :with => "a"
          click_button "Search"
        end
        
        assert page.has_link?("",    {:href => trip_ticket_path(@t01)})
        assert page.has_link?("",    {:href => trip_ticket_path(@t02)})
        assert page.has_no_link?("", {:href => trip_ticket_path(@t03)})
        assert page.has_link?("",    {:href => trip_ticket_path(@t04)})
        assert page.has_no_link?("", {:href => trip_ticket_path(@t05)})
        assert page.has_no_link?("", {:href => trip_ticket_path(@t06)})
        assert page.has_no_link?("", {:href => trip_ticket_path(@t07)})
        assert page.has_link?("",    {:href => trip_ticket_path(@t08)})
        assert page.has_no_link?("", {:href => trip_ticket_path(@t09)})
        assert page.has_link?("",    {:href => trip_ticket_path(@t10)})
        assert page.has_no_link?("", {:href => trip_ticket_path(@t11)})
        assert page.has_no_link?("", {:href => trip_ticket_path(@t12)})
        assert page.has_no_link?("", {:href => trip_ticket_path(@t13)})
        assert page.has_link?("",    {:href => trip_ticket_path(@t14)})
        assert page.has_no_link?("", {:href => trip_ticket_path(@t15)})
      
        within('#trip_ticket_filters') do
          fill_in "trip_ticket_filters_customer_identifiers", :with => "b"
          click_button "Search"
        end

        assert page.has_link?("",    {:href => trip_ticket_path(@t01)})
        assert page.has_link?("",    {:href => trip_ticket_path(@t02)})
        assert page.has_no_link?("", {:href => trip_ticket_path(@t03)})
        assert page.has_no_link?("", {:href => trip_ticket_path(@t04)})
        assert page.has_no_link?("", {:href => trip_ticket_path(@t05)})
        assert page.has_link?("",    {:href => trip_ticket_path(@t06)})
        assert page.has_no_link?("", {:href => trip_ticket_path(@t07)})
        assert page.has_link?("",    {:href => trip_ticket_path(@t08)})
        assert page.has_no_link?("", {:href => trip_ticket_path(@t09)})
        assert page.has_no_link?("", {:href => trip_ticket_path(@t10)})
        assert page.has_no_link?("", {:href => trip_ticket_path(@t11)})
        assert page.has_link?("",    {:href => trip_ticket_path(@t12)})
        assert page.has_no_link?("", {:href => trip_ticket_path(@t13)})
        assert page.has_link?("",    {:href => trip_ticket_path(@t14)})
        assert page.has_no_link?("", {:href => trip_ticket_path(@t15)})
      
        within('#trip_ticket_filters') do
          fill_in "trip_ticket_filters_customer_identifiers", :with => "d"
          click_button "Search"
        end

        assert page.has_link?("",    {:href => trip_ticket_path(@t01)})
        assert page.has_no_link?("", {:href => trip_ticket_path(@t02)})
        assert page.has_no_link?("", {:href => trip_ticket_path(@t03)})
        assert page.has_no_link?("", {:href => trip_ticket_path(@t04)})
        assert page.has_no_link?("", {:href => trip_ticket_path(@t05)})
        assert page.has_no_link?("", {:href => trip_ticket_path(@t06)})
        assert page.has_no_link?("", {:href => trip_ticket_path(@t07)})
        assert page.has_no_link?("", {:href => trip_ticket_path(@t08)})
        assert page.has_no_link?("", {:href => trip_ticket_path(@t09)})
        assert page.has_no_link?("", {:href => trip_ticket_path(@t10)})
        assert page.has_no_link?("", {:href => trip_ticket_path(@t11)})
        assert page.has_no_link?("", {:href => trip_ticket_path(@t12)})
        assert page.has_no_link?("", {:href => trip_ticket_path(@t13)})
        assert page.has_no_link?("", {:href => trip_ticket_path(@t14)})
        assert page.has_no_link?("", {:href => trip_ticket_path(@t15)})
      end
    end
  end

  private

  def fill_in_minimum_required_trip_ticket_fields
    within('#originator') do
      fill_in "Customer ID", :with => "ABC123"
    end

    within('#customer') do
      fill_in 'Address Line 1', :with => '123 Some Place'
      fill_in 'City', :with => 'Some City'
      fill_in 'State', :with => 'ST'
      fill_in 'Postal Code', :with => '12345'
    end
    
    within('#pick_up_location') do
      fill_in 'Address Line 1', :with => '456 Some Place'
      fill_in 'City', :with => 'Some City'
      fill_in 'State', :with => 'ST'
      fill_in 'Postal Code', :with => '12345'
    end
  
    within('#drop_off_location') do
      fill_in 'Address Line 1', :with => '789 Some Place'
      fill_in 'City', :with => 'Some City'
      fill_in 'State', :with => 'ST'
      fill_in 'Postal Code', :with => '12345'
    end

    fill_in 'First Name', :with => 'Phil'
    fill_in 'Last Name', :with => 'Scott'
    fill_in 'Primary Phone Number', :with => '555-1212'
    select 'No', :from => 'Information Withheld?'    
    select_date 30.years.ago, :from => :trip_ticket_customer_dob
    select 'Pickup', :from => 'Scheduling priority'
  end

  def select_date(date, options = {})  
    raise ArgumentError, 'from is a required option' if options[:from].blank?
    field = options[:from].to_s
    select date.year.to_s,               :from => "#{field}_1i"
    select Date::MONTHNAMES[date.month], :from => "#{field}_2i"
    select date.day.to_s,                :from => "#{field}_3i"
  end
end
