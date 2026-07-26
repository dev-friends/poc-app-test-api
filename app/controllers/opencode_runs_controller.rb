class OpencodeRunsController < ApplicationController
  def index
    runs = OpencodeRun.order(created_at: :desc).limit(50)
    render json: runs.map { |r| OpencodeRunSerializer.new(r).as_json }
  end

  def show
    run = OpencodeRun.find(params[:id])
    render json: OpencodeRunSerializer.new(run).as_json
  end

  def create
    run = OpencodeRun.new(
      status: :pending,
      prompt: params.require(:prompt),
      agent: params[:agent],
      model: params[:model],
      continue_session_id: params[:session_id]
    )
    run.save!
    RunOpencodePromptJob.perform_later(run.id)
    render json: OpencodeRunSerializer.new(run).as_json, status: :accepted
  end
end
