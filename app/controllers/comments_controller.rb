class CommentsController < ApplicationController
  before_action :require_login
  before_action -> { require_contribution(:comments) }

  def create
    @catch = Catch.find(params[:catch_id])
    @comment = @catch.comments.build(user: current_user, body: params.dig(:comment, :body))

    if @comment.save
      redirect_to catch_path(@catch, anchor: "comments"), notice: t("catch.add_comment")
    else
      redirect_to catch_path(@catch), alert: @comment.errors.full_messages.to_sentence
    end
  end
end
