class CommentsController < ApplicationController
  before_filter :login_required, :except => :index
  cache_sweeper :comment_sweeper, :only => [:create, :destroy]
  
  def index
    find_options = {
      :select => "MAX(id) AS id, parent_id",
      :page => params[:page],
      :order => "id DESC",
      :group => "parent_id"
    }
    @paging_comments = Comment.scoped({})
    @paging_comments = @paging_comments.by(current_user) if logged_in? && params[:mine]
    @paging_comments = @paging_comments.paginate(find_options)
    @comments = Comment.find(@paging_comments.map(&:id), :include => :user, :order => "id desc")
    @extra_comments = Comment.all(:conditions => [
      "parent_id IN (?) AND created_at >= ?", 
      @comments.map(&:parent_id), @comments.last.created_at
    ]).sort_by(&:id)
    @comments_by_parent_id = @extra_comments.group_by(&:parent_id)
  end
  
  def show
    @comment = Comment.find(params[:id])
    redirect_to_parent
  end
  
  def new
    @comment = Comment.new
  end
  
  def edit
    @comment = Comment.find(params[:id])
  end
  
  def create
    @comment = Comment.new(params[:comment])
    @comment.save unless params[:preview]
    respond_to do |format|
      format.html do
        if @comment.valid?
          flash[:notice] = "Your comment was saved."
          if params[:return_to]
            return redirect_to(params[:return_to])
          end
        else
          flash[:error] = "We had trouble saving your comment: " +
            @comment.errors.full_messages.join(', ')
        end
        redirect_to_parent
      end
      format.js
    end
  end
  
  def update
    @comment = Comment.find(params[:id])
    @comment.attributes = params[:comment]
    @comment.save unless params[:preview]
    respond_to do |format|
      format.html do
        if @comment.valid?
          flash[:notice] = "Your comment was saved."
        else
          flash[:error] = "We had trouble saving your comment: " +
            @comment.errors.full_messages.join(', ')
        end
        redirect_to_parent
      end
      format.js
    end
  end
  
  def destroy
    @comment = Comment.find(params[:id])
    parent = @comment.parent
    @comment.destroy
    respond_to do |format|
      format.html { redirect_to_parent }
    end
  end
  
  private
  def redirect_to_parent
    if @comment.parent.is_a?(Post)
      redirect_to post_path(@comment.parent.user.login, @comment.parent)
    else
      redirect_to(url_for(@comment.parent) + "#comment-#{@comment.id}")
    end
  end
end
