class DiscussesController < ApplicationController
	# 
	#layout false, :only =>[:list_by_course]
	before_filter :checkLogin, :only=>[:new, :update, :like, :create, :update, :delete]
	#before_filter :checkOwner, :only=>[:update, :delete]


	def index
		if current_user && params[:mine]=="true"
			@q=Discuss.search({:user_id_eq=>current_user.id})
		else
			@q = Discuss.search_by_text(params[:custom_search])
		end
		@discusses=@q.result(distinct: true).includes(:course_teachership, :sub_discusses, :user).page(params[:page]).order("id DESC")	
		#@ct=CourseTeachership.find(1)
	end
	
	def show
		@discuss=Discuss.includes(:sub_discusses, :course_teachership, :course_details).find(params[:id])
		discuss_id=@discuss.id.to_s
		@result=@discuss.to_json_obj(current_user.try(:id))
	end

  def new
		@discuss = Discuss.new
		@q=CourseTeachership.search(params[:q])
		if params[:ct_id].present?
			@ct=CourseTeachership.find(params[:ct_id])
		end
		@imgsrc=current_user.hasFb? ? "http://graph.facebook.com/#{current_user.uid}/picture" : ActionController::Base.helpers.asset_path("anonymous.jpg")
		render "main_form"
	end
	
	def edit	#only for main discuss
		@discuss=current_user.discusses.find(params[:id])
		@q=CourseTeachership.search(params[:q])
		@ct=@discuss.course_teachership
		@imgsrc=current_user.hasFb? ? "http://graph.facebook.com/#{current_user.uid}/picture" : ActionController::Base.helpers.asset_path("anonymous.jpg")
		render "main_form"
	end
	
	def create        
		if params[:type].blank?
			@discuss=current_user.discusses.create(main_discuss_params.merge({:likes=>0,:dislikes=>0}))
		elsif params[:type]=="sub"
			@discuss=current_user.sub_discusses.create(sub_discuss_params.merge({:likes=>0,:dislikes=>0}))
		end
		if !request.xhr?
			redirect_to :action => :index
		end	
	end
	
	def update	
		if params[:type].blank?
			@discuss=current_user.discusses.find(params[:id])
			@discuss.update(main_discuss_params)
			redirect_to :action=> :show, :id=>params[:id]
		elsif params[:type]=="sub"
			@sub_d=current_user.sub_discusses.find(params[:id])
			#@discuss.content=params[:content]
			@sub_d.update(sub_discuss_params)
			#@discuss.save!
			#redirect_to :action=> :show, :id=>@discuss.discuss_id
		end
		
	end
	
	def destroy
		if params[:type].blank?
			@discuss=current_user.discusses.find(params[:id])
			@discuss.destroy!
			redirect_to :action=> :index
		elsif params[:type]=="sub"
			@sub_d=current_user.sub_discusses.find(params[:id])
			#@sub_d_id=@discuss.discuss_id
			@sub_d.destroy!
			#redirect_to :action=> :show, :id=>@discuss_id
		end
		
		
	end
  
	def list_by_ct
		#@ct_id=
		@ct=CourseTeachership.includes(:course).find(params[:ct_id].to_i)
		@discusses=@ct.discusses.includes(:sub_discusses, :user, :discuss_likes).order("updated_at DESC")
		render :layout=>false
	end
	
	def like
		@like=current_user.discuss_likes.create(:like=>params[:like])
		
		case params[:type] 
			when "main"
				@like.discuss_id=params[:discuss_id]
				@discuss=Discuss.find(params[:discuss_id])
				unless @discuss.discuss_likes.select{|l|l.user_id==current_user.id}.empty?
					render :nothing => true, :status => 400, :content_type => 'text/html'
					return
				end
			when "sub"
				@like.sub_discuss_id=params[:discuss_id]
				@discuss=SubDiscuss.find(params[:discuss_id])
				unless @discuss.discuss_likes.select{|l|l.user_id==current_user.id}.empty?
					render :nothing => true, :status => 400, :content_type => 'text/html'
					return
				end
			else 
				return
		end
		@like.save!
		if @like.like
			@discuss.likes+=1
			@discuss.save!
		else
			@discuss.dislikes+=1
			@discuss.save!
		end
		render :nothing => true, :status => 200, :content_type => 'text/html'	
		
	end
	
	private

	def main_discuss_params
		params.require(:discuss).permit(:title, :content, :is_anonymous, :course_teachership_id)
	end
	def sub_discuss_params
		params.require(:sub_discuss).permit(:content, :discuss_id)
	end
end
