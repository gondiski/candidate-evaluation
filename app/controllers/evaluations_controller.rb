class EvaluationsController < ApplicationController
  before do
    authenticate!
  end

  get "/" do
    @evaluations = Evaluation.where(user_id: current_user.id).order(Sequel.desc(:created_at)).all
    erb :"evaluations/index"
  end

  get "/new" do
    @evaluation = Evaluation.new
    erb :"evaluations/new"
  end

  post "/" do
    @evaluation = Evaluation.new(
      user_id: current_user.id,
      title: params[:title],
      stage: "briefing"
    )
    
    if @evaluation.save
      flash[:notice] = "Evaluation created."
      redirect "/evaluations/#{@evaluation.id}"
    else
      flash[:error] = @evaluation.errors.full_messages.join(", ")
      erb :"evaluations/new"
    end
  end

  get "/:id" do
    @evaluation = Evaluation.where(user_id: current_user.id, id: params[:id]).first
    halt 404, "Evaluation not found" unless @evaluation
    
    @stage_runs = StageRun.where(evaluation_id: @evaluation.id).order(Sequel.desc(:created_at)).all
    erb :"evaluations/show"
  end

  get "/:id/edit" do
    @evaluation = Evaluation.where(user_id: current_user.id, id: params[:id]).first
    halt 404, "Evaluation not found" unless @evaluation
    
    erb :"evaluations/edit"
  end

  put "/:id" do
    @evaluation = Evaluation.where(user_id: current_user.id, id: params[:id]).first
    halt 404, "Evaluation not found" unless @evaluation
    
    if @evaluation.update(title: params[:title])
      flash[:notice] = "Evaluation updated."
      redirect "/evaluations/#{@evaluation.id}"
    else
      flash[:error] = @evaluation.errors.full_messages.join(", ")
      erb :"evaluations/edit"
    end
  end

  delete "/:id" do
    @evaluation = Evaluation.where(user_id: current_user.id, id: params[:id]).first
    halt 404, "Evaluation not found" unless @evaluation
    
    @evaluation.purge!
    flash[:notice] = "Evaluation purged."
    redirect "/evaluations"
  end

  # Purge endpoint for hard delete
  post "/:id/purge" do
    @evaluation = Evaluation.where(user_id: current_user.id, id: params[:id]).first
    halt 404, "Evaluation not found" unless @evaluation
    
    @evaluation.purge!
    flash[:notice] = "Evaluation purged with all data."
    redirect "/evaluations"
  end
end
