class Api::ItemsController < Api::BaseController
  prepend_before_filter :normalize_identifier, only: [:show]
  before_filter :validate_permissions!, only: [:show]
  before_filter :item, only: [:show]
  before_filter :set_current_user!, only: [:index]

  self.solr_search_params_logic = [
    :default_solr_parameters,
    :add_query_to_solr,
    :add_paging_to_solr,
    :add_sorting_to_solr,
    :add_access_controls_to_solr_params,
    :enforce_embargo,
    :exclude_unwanted_models,
    :build_api_query
  ]

  # GET /api/items
  def index
    (@response, @document_list) = get_search_results
    render json: Api::ItemsSearchPresenter.new(@response, request.url, request.query_parameters).to_json
  end

  # GET /api/items/1
  def show
    render json: Api::ShowItemPresenter.new(item, request.url).to_json
  end

  private

    def item
      @this_item ||= ActiveFedora::Base.find(params[:id], cast: true)
    rescue ActiveFedora::ObjectNotFoundError
      user_name = @current_user.try(:username) || @current_user
      render json: { error: 'Item not found', user: user_name, item: params[:id] }, status: :not_found
    end

    def build_api_query(solr_parameters, user_parameters)
      # translate API query terms into solr query using API::QueryBuilder service
      Api::QueryBuilder.new(@current_user).build_filter_queries(solr_parameters, user_parameters)
    end
end
