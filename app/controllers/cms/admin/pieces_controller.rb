# encoding: utf-8
class Cms::Admin::PiecesController < Cms::Controller::Admin::Base
  include Sys::Controller::Scaffold::Base

  def pre_dispatch
    return error_auth unless Core.user.has_auth?(:designer)
    return redirect_to action: 'index' if params[:reset]
  end

  def index
    @items = Cms::Piece.search(params)
    @items = @items.readable if params[:s_target] != 'all'
    @items = @items.order(:name, :id)
                   .paginate(page: params[:page], per_page: params[:limit])

    _index @items
  end

  def show
    if params[:do] == 'preview'
      preview
    else
      exit
    end
  end

  def preview
    @item = Cms::Piece.find(params[:id])
    return error_auth unless @item.readable?

    render :preview
  end

  def new
    @item = Cms::Piece.new(concept_id: Core.concept(:id),
                           state: 'public')
    @contents = content_options(false)
    @models   = model_options(false)
  end

  def create
    @item = Cms::Piece.new(pices_params)
    @item.site_id = Core.site.id
    @contents = content_options(false)
    @models = model_options(false)

    _create @item do
      respond_to do |format|
        format.html { return redirect_to(@item.admin_uri) }
      end
    end
  end

  def update
    exit
  end

  def destroy
    @item = Cms::Piece.find(params[:id])
    _destroy @item
  end

  def content_options(rendering = true)
    contents = []

    concept_id = params[:concept_id]
    concept_id = @item.concept_id if @item && @item.concept_id
    concept_id ||= Core.concept.id
    concept = Cms::Concept.find_by(id: concept_id)

    if concept
      concept.parents_tree.each do |c|
        contents += Cms::Content.where(concept_id: c.id).order(:name, :id)
      end
    end

    @options = []
    @options << [Cms::Lib::Modules.module_name(:cms), '']
    @options += contents.collect do |c|
      concept_name = c.concept ? "#{c.concept.name} : " : nil
      ["#{concept_name}#{c.name}", c.id]
    end
    return @options unless rendering

    concept_name = concept ? "#{concept.name}:" : nil
    @options.unshift ["// ??????????????????????????????#{concept_name}#{contents.size + 1}??????", '']

    respond_to do |format|
      format.html { render layout: false }
    end
  end

  def model_options(rendering = true)
    content_id = params[:content_id]
    content_id = @item.content.id if @item && @item.content

    model = 'cms'
    content = Cms::Content.find_by(id: content_id)
    if content
      model = content.model
    end
    models = Cms::Lib::Modules.pieces(model)

    @options  = []
    @options += models
    return models unless rendering

    content_name = content ? content.name : Cms::Lib::Modules.module_name(:cms)
    @options.unshift ["// ??????????????????????????????#{content_name}:#{models.size}??????", '']

    respond_to do |format|
      format.html { render layout: false }
    end
  end

  private

  def pices_params
    params.require(:item).permit(
      :concept_id, :content_id, :state, :model, :name, :title, :view_title,
      in_creator: [:group_id, :user_id]
    )
  end
end
