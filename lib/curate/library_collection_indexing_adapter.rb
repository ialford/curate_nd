require 'curate/indexer/documents'

module Curate
  # An implementation of the required methods to integrate with the Curate::Indexer gem.
  # @see Curate::Indexer::Adapters::AbstractAdapter
  module LibraryCollectionIndexingAdapter
    # @api public
    # @param pid [String]
    # @return Curate::Indexer::Documents::PreservationDocument
    def self.find_preservation_document_by(pid)
      # Not everything is guaranteed to have library_collection_ids
      # If it doesn't have it, what do we do?
      fedora_object = ActiveFedora::Base.find(pid, cast: true)
      if fedora_object.respond_to?(:library_collection_ids)
        parent_pids = fedora_object.library_collection_ids
      else
        parent_pids = []
      end
      Curate::Indexer::Documents::PreservationDocument.new(pid: pid, parent_pids: parent_pids)
    end

    # @api public
    # @yield Curate::Indexer::Documents::PreservationDocument
    def self.each_preservation_document
      query = "pid~#{Sufia.config.id_namespace}:*"
      ActiveFedora::Base.send(:connections).each do |conn|
        conn.search(query) do |object|
          next if object.pid.start_with?(ReindexWorker::FEDORA_SYSTEM_PIDS)
          # Because I have a Rubydora object, I need to find it via ActiveFedora, thus the reuse.
          yield(find_preservation_document_by(object.pid))
        end
      end
    end

    # @api public
    # @param pid [String]
    # @return Curate::Indexer::Documents::IndexDocument
    def self.find_index_document_by(pid)
      solr_document = find_solr_document_by(pid)
      coerce_solr_document_to_index_document(solr_document)
    end

    # @api public
    # @param document [Curate::Indexer::Documents::IndexDocument]
    # @param curation_concern_type [nil, ActiveFedora::Base] filter on this and only this type of curation concern
    # @yield Curate::Indexer::Documents::IndexDocument
    def self.each_child_document_of(parent_document, curation_concern_type = nil, &block)
      raw_child_documents_of(parent_document, curation_concern_type).each do |solr_document|
        yield(coerce_solr_document_to_index_document(solr_document))
      end
    end

    # @api private
    # @param document [Curate::Indexer::Documents::IndexDocument]
    # @param curation_concern_type [nil, ActiveFedora::Base] filter on this and only this type of curation concern
    # @note This is a reindexing process to add the collection data... the items must have been initially indexed to be included.
    # @return [Hash] A raw response document from SOLR
    def self.raw_child_documents_of(parent_document, curation_concern_type = nil)
      escaped_pid = ActiveFedora::SolrService.escape_uri_for_query("info:fedora/#{parent_document.pid}")
      qry = "is_member_of_collection_ssim:#{escaped_pid}"
      fq = "active_fedora_model_ssi:#{curation_concern_type}" unless curation_concern_type.nil?
      # Specifying a number of rows so:
      #   1) it can be changed for development testing with fewer collections, or
      #   2) to easily know page size to compare to numFound, rather than pulling the 'default' that was used from the solr response
      #   3) to select a number large enough to remove the need for the second query in most situations
      rows = 100

      solr_response = get_page_from_solr(qry: qry, params: { fq: fq, rows: rows } )
      total_docs = solr_response['response']['numFound']

      if total_docs > rows
        solr_response = get_page_from_solr(qry: qry, params: { fq: fq, rows: total_docs } )
      end

      solr_response['response']['docs']
    end

    # @api public
    # @param attributes [Hash]
    # @option pid [String]
    # @return Hash
    def self.write_document_attributes_to_index_layer(attributes = {})
      # As much as I'd love to use the SOLR document, I don't believe this is feasable as not all elements of the
      # document are stored and returned.
      fedora_object = ActiveFedora::Base.find(attributes.fetch(:pid), cast: true)
      solr_document = fedora_object.to_solr

      solr_document[SOLR_KEY_PARENT_PIDS] = attributes.fetch(:parent_pids)
      solr_document[SOLR_KEY_PARENT_PIDS_FACETABLE] = attributes.fetch(:parent_pids)
      solr_document[SOLR_KEY_ANCESTORS] = attributes.fetch(:ancestors)
      solr_document[SOLR_KEY_ANCESTOR_SYMBOLS] = attributes.fetch(:ancestors)
      solr_document[SOLR_KEY_PATHNAMES] = attributes.fetch(:pathnames)
      solr_document[SOLR_KEY_PATHNAMES_FACETABLE] = attributes.fetch(:pathnames)
      display_hierarchy = build_pathname_display_hierarchy(attributes.fetch(:pathnames))
      solr_document[SOLR_KEY_PATHNAME_HIERARCHY_WITH_TITLES] = display_hierarchy
      solr_document[SOLR_KEY_PATHNAME_HIERARCHY_WITH_TITLES_FACETABLE] = display_hierarchy

      ActiveFedora::SolrService.add(solr_document)
      ActiveFedora::SolrService.commit
      solr_document
    end

    SOLR_KEY_PARENT_PIDS = ActiveFedora::SolrService.solr_name(:library_collections).freeze
    SOLR_KEY_PARENT_PIDS_FACETABLE = ActiveFedora::SolrService.solr_name(:library_collections, :facetable).freeze
    SOLR_KEY_ANCESTORS = ActiveFedora::SolrService.solr_name(:library_collections_ancestors).freeze
    # Adding the ancestor symbol as a means of looking up relations; This is cribbed from our current version of ActiveFedora's
    # relationship
    SOLR_KEY_ANCESTOR_SYMBOLS = ActiveFedora::SolrService.solr_name(:library_collections_ancestors, :symbol).freeze
    SOLR_KEY_PATHNAMES = ActiveFedora::SolrService.solr_name(:library_collections_pathnames).freeze
    SOLR_KEY_PATHNAMES_FACETABLE = ActiveFedora::SolrService.solr_name(:library_collections_pathnames, :facetable).freeze
    SOLR_KEY_PATHNAME_HIERARCHY_WITH_TITLES = ActiveFedora::SolrService.solr_name(:library_collections_pathnames_hierarchy_with_titles).freeze
    SOLR_KEY_PATHNAME_HIERARCHY_WITH_TITLES_FACETABLE = ActiveFedora::SolrService.solr_name(:library_collections_pathnames_hierarchy_with_titles, :facetable).freeze

    def self.coerce_solr_document_to_index_document(solr_document, pid = solr_document.fetch('id'))
      parent_pids = solr_document.fetch(SOLR_KEY_PARENT_PIDS, [])
      ancestors = solr_document.fetch(SOLR_KEY_ANCESTORS, [])
      pathnames = solr_document.fetch(SOLR_KEY_PATHNAMES, [])
      Curate::Indexer::Documents::IndexDocument.new(
        pid: pid,
        parent_pids: parent_pids,
        pathnames: pathnames,
        ancestors: ancestors
      )
    end
    private_class_method :coerce_solr_document_to_index_document

    def self.embed_pid_in_title(pid, title, delimiter: '|')
      if title.blank?
        pid
      else
        "#{title}#{delimiter}#{pid}"
      end
    end
    private_class_method :embed_pid_in_title

    def self.build_pathname_display_hierarchy(pathnames, delimiter: '/')
      pathnames = Array.wrap(pathnames)
      return nil unless pathnames.any?
      pathnames_with_titles = []
      pathnames.each do |pathname|
        pids = Array.wrap(pathname.split(delimiter))
        pids.pop # we are only interested in parent pids
        next unless pids.any?
        objects = pids.collect{ |pid| ActiveFedora::Base.find(pid, cast: true) }
        objects.count.times do
          pathnames_with_titles << objects.collect{ |object| embed_pid_in_title(object.pid, object.title) }.join(delimiter)
          objects.pop
        end
      end
      pathnames_with_titles
    end
    private_class_method :build_pathname_display_hierarchy

    def self.find_solr_document_by(pid)
      query = ActiveFedora::SolrService.construct_query_for_pids([pid])
      ActiveFedora::SolrService.query(query).first
    end
    private_class_method :find_solr_document_by

    def self.get_page_from_solr(qry:, params: request_params)
      ActiveFedora::SolrService.query(qry, raw: true, **params)
    end
    private_class_method :get_page_from_solr
  end
end
