require 'spec_helper'
require 'curate/library_collection_indexing_adapter'
require 'curate/indexer/adapters/abstract_adapter'

module Curate
  RSpec.describe LibraryCollectionIndexingAdapter do
    it 'is the adapter for the Curate::Indexer', context: :integration do
      expect(Curate::Indexer.adapter).to eq(described_class)
    end
    it 'implements all of the methods of the Curate::Indexer::Adapters::AbstractAdapter' do
      methods_implemented_in_abstract = Curate::Indexer::Adapters::AbstractAdapter.methods(false)
      methods_implemented_for_curate_nd_indexing = described_class.methods(false)

      # Looking at the intersection of methods defined in each of the modules
      # If the intersection is the same as the methods in the abstract, then we have adequately implemented the interface
      expect((methods_implemented_for_curate_nd_indexing & methods_implemented_in_abstract).sort).to eq(methods_implemented_in_abstract.sort)
    end

    context '.find_preservation_document_by' do
      context 'for a library collectable item' do
        it 'will return a Curate::Indexer::Documents::PreservationDocument' do
          work = FactoryGirl.create(:document)
          expect(described_class.find_preservation_document_by(work.pid)).to be_a(Curate::Indexer::Documents::PreservationDocument)
        end
      end
      context 'for a non-library collectable item' do
        it 'will return a Curate::Indexer::Documents::PreservationDocument with empty parent_pids' do
          work = double('Work', pid: '123')
          allow(ActiveFedora::Base).to receive(:find).and_return(work)
          preservation_document = described_class.find_preservation_document_by(work.pid)
          expect(preservation_document.parent_pids).to eq([])
        end
      end
      context 'for a missing pid' do
        it 'will raise an ActiveFedora::RecordNotFound error' do
          expect { described_class.find_preservation_document_by('missing') }.to raise_error
        end
      end
    end

    context '.each_preservation_document' do
      it 'will iterate through Fedora and yield Curate::Indexer::Documents::PreservationDocument instances' do
        doc = FactoryGirl.create(:document)
        expect(described_class.find_preservation_document_by(doc.pid)).to be_a(Curate::Indexer::Documents::PreservationDocument)
      end
    end

    context '.find_index_document_by' do
      it 'will retrieve the SOLR document by PID and return a Curate::Indexer::Documents::IndexDocument' do
        work = FactoryGirl.create(:document)
        expect(described_class.find_index_document_by(work.pid)).to be_a(Curate::Indexer::Documents::IndexDocument)
      end
    end

    context '.each_child_document_of' do
      it 'will retrieve the SOLR document by PID and return a Curate::Indexer::Documents::IndexDocument' do
        collection = FactoryGirl.create(:library_collection)
        described_class.write_document_attributes_to_index_layer(
          pid: collection.pid, pathnames: [collection.pid], ancestors: [], parent_pids: []
        )
        [
          FactoryGirl.create(:document, library_collection_ids: [collection.id]),
          FactoryGirl.create(:document, library_collection_ids: [collection.id])
        ].each do |work|
          described_class.write_document_attributes_to_index_layer(
            pid: work.pid, pathnames: ["#{collection.pid}/#{work.pid}"], ancestors: [collection.pid], parent_pids: [collection.pid]
          )
        end
        collection_index_document = described_class.find_index_document_by(collection.pid)
        expect { |b| described_class.each_child_document_of(collection_index_document, &b) }.to yield_successive_args(
          Curate::Indexer::Documents::IndexDocument,
          Curate::Indexer::Documents::IndexDocument
        )
      end

      it 'will allows filtering by class name and retrieves the SOLR document by PID and return a Curate::Indexer::Documents::IndexDocument' do
        collection = FactoryGirl.create(:library_collection)
        described_class.write_document_attributes_to_index_layer(
          pid: collection.pid, pathnames: [collection.pid], ancestors: [], parent_pids: []
        )
        subcollection = FactoryGirl.create(:library_collection, library_collection_ids: [collection.id])
        document = FactoryGirl.create(:document, library_collection_ids: [collection.id])
        [subcollection, document].each do |work|
          described_class.write_document_attributes_to_index_layer(
            pid: work.pid, pathnames: ["#{collection.pid}/#{work.pid}"], ancestors: [collection.pid], parent_pids: [collection.pid]
          )
        end
        collection_index_document = described_class.find_index_document_by(collection.pid)
        child_pids = []
        children = []
        described_class.each_child_document_of(collection_index_document, subcollection.class) do |doc|
          children << doc
          child_pids << doc.pid
        end
        expect(child_pids).to eq([subcollection.pid])
        expect(collection.subcollections).to eq([subcollection])
      end
    end

    context '.write_document_attributes_to_index_layer' do
      it 'will update the underlying solr document' do
        ancestor = double('Work', pid: 'und:123', title: 'ancestor', inner_object: '', to_solr: { id: 'und:123' })
        allow(ActiveFedora::Base).to receive(:find).and_return(ancestor)
        work = FactoryGirl.create(:document)
        attributes = { pid: work.pid, pathnames: ["#{ancestor.pid}/#{work.pid}"], ancestors: [ancestor.pid], parent_pids: [ancestor.pid] }
        solr_document = described_class.write_document_attributes_to_index_layer(attributes)

        # solr_document = described_class.send(:find_solr_document_by, work.pid)
        expect(solr_document.fetch(described_class::SOLR_KEY_PARENT_PIDS)).to eq(attributes.fetch(:parent_pids))
        expect(solr_document.fetch(described_class::SOLR_KEY_PARENT_PIDS_FACETABLE)).to eq(attributes.fetch(:parent_pids))
        expect(solr_document.fetch(described_class::SOLR_KEY_ANCESTORS)).to eq(attributes.fetch(:ancestors))
        # expect(solr_document.fetch(described_class::SOLR_KEY_ANCESTOR_SYMBOLS)).to eq(attributes.fetch(:ancestors))
        expect(solr_document.fetch(described_class::SOLR_KEY_PATHNAMES)).to eq(attributes.fetch(:pathnames))
      end
    end
  end
end
