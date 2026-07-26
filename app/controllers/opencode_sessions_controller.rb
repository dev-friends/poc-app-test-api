class OpencodeSessionsController < ApplicationController
  def index
    stdout, stderr, status = OpencodeCli.exec("session", "list")
    render json: { output: status.success? ? stdout : stderr }, status: status.success? ? :ok : :unprocessable_content
  end

  def destroy
    stdout, stderr, status = OpencodeCli.exec("session", "delete", params[:id])
    render json: { output: status.success? ? stdout : stderr }, status: status.success? ? :ok : :unprocessable_content
  end
end
