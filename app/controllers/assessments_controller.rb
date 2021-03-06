class AssessmentsController < ApplicationController
  before_filter :authenticate_user!, :except => [:index, :show, :show_section]
  before_filter :load_assessment, :only => [:edit, :update, :destroy, :show]
  before_filter :load_project
  before_filter :project_curator_required, :except => [:index, :show, :show_section]

  def new
    @assessment = Assessment.new
    @assessment.project = @project
    @assessment.sections.build
  end

  def create
    @assessment = Assessment.new(params[:assessment])
    @assessment.user ||= current_user
    @assessment.project = @project

    @assessment.sections.build if @assessment.sections == []
    @assessment.sections.map {|section| section.user = current_user }

    if @assessment.completed_at.blank? && params['completed'].present?
      @assessment.completed_at = Time.now
    end
    if @assessment.completed_at.present? && params['completed'].blank?
      @assessment.completed_at = nil
    end

    @parent_display_name = @assessment.taxon_name
    if params[:preview]
      @headless = @footless = true
      render :partial => 'show' 
      return
    end

    respond_to do |format|
      if @assessment.valid? && ! params[:preview]
        @assessment.save
        format.html { redirect_to(@assessment, :notice => 'Assessment was successfully created.') }
      else
        format.html { render :action => "new" }
      end
    end
  end

  def update
    @parent_display_name = @assessment.taxon_name
    if @assessment.completed_at.blank? && params['completed'].present?
      @assessment.completed_at = Time.now
    end
    if @assessment.completed_at.present? && params['completed'].blank?
      @assessment.completed_at = nil
    end
    if params[:preview]
      @assessment.assign_attributes(params[:assessment])
      @headless = @footless = true
      render :partial => 'show' 
      return
    end

    respond_to do |format|
    if @assessment.update_attributes(params[:assessment])
        format.html { redirect_to(@assessment, :notice => 'Assessment was successfully updated.') }
      else
        format.html { render :action => "edit" }
      end
    end
  end

  def show
    if params[:iframe]
      @headless = @footless = true
    end
    @parent_display_name = @assessment.taxon_name
    respond_to do |format|
      format.html
    end
  end

  def edit
  end

  def index
    @parent_display_name = @project.title
    respond_to do |format|
      format.html do
        @assessments = Assessment.where(:project_id => @project.id).includes(:taxon, :sections).order("taxa.name ASC").
          paginate(:page => params[:page]).scoped
        if filters = params[:filters]
          @complete = filters[:complete]
          @complete = nil unless %w(yes no).include?(@complete)
          if @complete == 'yes'
            @assessments = @assessments.complete
          elsif @complete == 'no'
            @assessments = @assessments.incomplete
          end
          @q = filters[:q]
          @assessments = @assessments.dbsearch(@q) unless @q.blank?
        end
        @authority = params[:authority]
        @status = params[:status]
        if @authority && @status
          @assessments = @assessments.with_conservation_status(@authority, @status, nil)
        end
        section_ids = @assessments.map{|a| a.sections.map(&:id)}.flatten.uniq
        @comment_counts = Comment.group(:parent_id).where("parent_type = 'AssessmentSection' AND parent_id IN (?)", section_ids).count
        @conservation_statuses = ConservationStatus.
          joins(:taxon => :assessments).
          where("assessments.project_id = ?", @project).count
        statuses = ConservationStatus.select("max(conservation_statuses.id), authority, status").joins(:taxon => :assessments).
          where("assessments.project_id = ?", @project).group(:authority, :status)
        @conservation_statuses = statuses.inject({}) do |memo, status|
          memo[status.authority] ||= []
          memo[status.authority] << status.status
          memo
        end
      end
      format.json do
        @assessments = @project.assessments.includes("taxon").order("taxa.name ASC").page(params[:page]).per_page(100)
        @assessments = if params[:complete] == 'true'
          @assessments.complete
        elsif params[:complete] == 'false'
          @assessments.incomplete
        end
        render :json => @assessments
      end
    end
  end


  def destroy
    @assessment.destroy
    redirect_to(@assessment.project, :notice => 'Assessment was deleted.')
  end

  def show_section
    @section = Section.find(params[:id])
    @section.delete!
    @project = @assessment.project
    redirect_to assessment_section_path(@project), :anchor => 'fragment_identifier'
  end

  private

  def load_project
    @project = Project.find(params[:project_id]) rescue nil
    @project ||= Project.find_by_id(params[:assessment][:project_id]) unless params[:assessment].blank?
    @project ||= @assessment.project if @assessment
    render_404 unless @project
    true
  end
  
  def project_curator_required
    unless @project.curated_by?(current_user)
      flash[:error] = "You don't have permission to edit that project."
      return redirect_to @project
    end
    true
  end

  def load_assessment
    @assessment = Assessment.find(params[:id]) rescue nil
    render_404 unless @assessment
  end

end # class
