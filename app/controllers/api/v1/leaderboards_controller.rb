module Api::V1
class LeaderboardsController < ApplicationController

  def index
    if params[:tag]
      @leaderboards = authorized_app.leaderboards.tagged_with(params[:tag].to_s).order(:priority)
    else
      @leaderboards = authorized_app.leaderboards.order(:priority)
    end
    render json: @leaderboards.map {|x| x.api_fields(request_base_uri, in_sandbox?)}
  end

  def show
    err_message = nil
    lid = params[:id] && params[:id].to_i
    err_message = "You must pass a leaderboard id" unless lid

    if !err_message
      @leaderboard = authorized_app.leaderboards.find_by_id(lid)
      err_message = "Your app does not have a leaderboard with id: #{lid}" unless @leaderboard
    end

    if !err_message
      render json: @leaderboard.api_fields(request_base_uri, in_sandbox?)
    else
      render status: :bad_request, json: {message: err_message}
    end
  end

  def create
    @leaderboard = authorized_app.leaderboards.new(params[:leaderboard])
    if @leaderboard.save
      render json: @leaderboard.api_fields(request_base_uri, in_sandbox?), status: :created
    else
      render json: @leaderboard.errors, status: :unprocessable_entity 
    end
  end
end
end