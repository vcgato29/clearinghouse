class TripClaimsController < ApplicationController
  load_and_authorize_resource :trip_ticket
  load_and_authorize_resource :trip_claim, :through => :trip_ticket
  skip_authorize_resource :trip_claim, :only => :popup_info
  
  # GET /trip_claims
  # GET /trip_claims.json
  def index
    respond_to do |format|
      format.html # index.html.erb
      format.json { render json: @trip_claims }
      format.js
    end
  end

  # GET /trip_claims/1
  # GET /trip_claims/1.json
  def show
    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @trip_claim }
    end
  end

  # GET /trip_claims/new
  # GET /trip_claims/new.json
  def new
    @trip_claim.claimant = current_user.provider
    respond_to do |format|
      format.html # new.html.erb
      format.json { render json: new_trip_claim_instance_as_json_for_backbone }
    end
  end

  # GET /trip_claims/1/edit
  def edit
    respond_to do |format|
      format.html 
    end
  end

  def popup_info
    respond_to do |format|
      data = render_to_string(partial: "popup_form", locals: { object: @trip_claim }, formats: [:html])
      format.json { render json: {rendered_partial: data }.to_json }
    end
  end

  # POST /trip_claims
  # POST /trip_claims.json
  def create
    @trip_claim.claimant = current_user.provider
    @trip_claim.status = :pending
    respond_to do |format|
      if @trip_claim.save
        @trip_claim.reload
        notice = 'Trip claim was successfully created.'
        notice += ' Your claim has been automatically approved.' if @trip_claim.approved?
        format.html { redirect_to [@trip_ticket, @trip_claim], notice: notice }
        format.json { head :no_content }
      else
        format.html { render action: "new" }
        format.json { render json: {rendered_partial: render_to_string(partial: "shared/error_explanation", locals: { object: @trip_claim }, formats: [:html])}.to_json, status: :unprocessable_entity }
      end
    end
  end

  # PUT /trip_claims/1
  # PUT /trip_claims/1.json
  def update
    respond_to do |format|
      if @trip_claim.update_attributes(trip_claim_params)
        format.html { redirect_to [@trip_ticket, @trip_claim], notice: 'Trip claim was successfully updated.' }
        format.json { head :no_content }
      else
        format.html { render action: "edit" }
        format.json { render json: {rendered_partial: render_to_string(partial: "shared/error_explanation", locals: { object: @trip_claim }, formats: [:html])}.to_json, status: :unprocessable_entity }
      end
    end
  end

  def rescind
    @trip_claim.rescind!
    
    respond_to do |format|
      format.html { redirect_to @trip_ticket, notice: 'Trip claim was successfully rescinded.' }
      format.json { head :no_content }
    end
  end

  # PUT /trip_claims/1/approve
  def approve
    @trip_claim.approve!
    
    respond_to do |format|
      format.html { redirect_to @trip_ticket, notice: 'Trip claim was successfully approved.' }
      format.json { head :no_content }
    end
  end

  # PUT /trip_claims/1/decline
  def decline
    @trip_claim.decline!
    
    respond_to do |format|
      format.html { redirect_to @trip_ticket, notice: 'Trip claim was successfully declined.' }
      format.json { head :no_content }
    end
  end

  # this helps to whitelist trip claim params in TripTicketsController#create_multiple_claims
  def self.permitted_params
    [ :claimant_customer_id, :claimant_provider_id, :claimant_service_id, :claimant_trip_id,
      :status, :trip_ticket_id, :proposed_pickup_time, :proposed_fare, :notes ]
  end

  private

  def trip_claim_params
    params.require(:trip_claim).permit(*TripClaimsController.permitted_params)
  end

  def new_trip_claim_instance_as_json_for_backbone
    @trip_claim.attributes.merge({
      rendered_partial: render_to_string(partial: "trip_claims/form", formats: [:html]),
    }).to_json
  end
end
