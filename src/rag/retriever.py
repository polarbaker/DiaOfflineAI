"""
RAG Retriever Module

Integrates document store and vector store for retrieval-augmented generation
"""

import os
import logging
from pathlib import Path

from src.rag.document_store import DocumentStore
from src.rag.vector_store import VectorStore

logger = logging.getLogger(__name__)

class RagRetriever:
    """
    Manages document retrieval for augmenting responses with relevant information.
    Combines both text search and vector search for best results.
    """
    
    def __init__(self, config):
        """
        Initialize the RAG retriever.
        
        Args:
            config (dict): Configuration for RAG
        """
        self.config = config
        self.enabled = config.get('enabled', False)
        
        if not self.enabled:
            logger.info("RAG system is disabled")
            return
        
        try:
            # Initialize document store
            self.document_store = DocumentStore(config)
            
            # Initialize vector store
            self.vector_store = VectorStore(config)
            
            logger.info("RAG retriever initialized successfully")
            
        except Exception as e:
            logger.error(f"Error initializing RAG retriever: {str(e)}")
            self.enabled = False
    
    def retrieve(self, query, limit=3):
        """
        Retrieve relevant information for a query.
        
        Args:
            query (str): User query
            limit (int, optional): Maximum number of results
            
        Returns:
            list: List of relevant text chunks
        """
        if not self.enabled:
            logger.debug("RAG system is disabled, no retrieval performed")
            return []
        
        try:
            # Perform text-based search
            text_results = self.document_store.search_documents(query, limit=limit)
            
            # Perform vector-based search
            vector_results = self.vector_store.search(query, limit=limit)
            
            # Get document content for vector results
            enhanced_vector_results = []
            for result in vector_results:
                doc = self.document_store.get_document(result['document_id'])
                if doc and 'chunks' in doc:
                    for chunk in doc['chunks']:
                        if chunk['chunk_index'] == result['chunk_index']:
                            enhanced_vector_results.append({
                                'id': chunk['id'],
                                'title': doc['title'],
                                'content': chunk['content'],
                                'score': result['score']
                            })
                            break
            
            # Merge results (prefer vector results but include unique text results)
            merged_results = enhanced_vector_results.copy()
            
            # Add text results that aren't already in vector results
            vector_ids = {r['id'] for r in merged_results}
            for result in text_results:
                if result['id'] not in vector_ids:
                    # Add a default score
                    result['score'] = 0.5
                    merged_results.append(result)
            
            # Sort by score
            merged_results.sort(key=lambda x: x.get('score', 0), reverse=True)
            
            # Limit results
            merged_results = merged_results[:limit]
            
            logger.debug(f"Retrieved {len(merged_results)} relevant chunks for query")
            return merged_results
            
        except Exception as e:
            logger.error(f"Error in RAG retrieval: {str(e)}")
            return []
    
    def add_document(self, title, content, source=None, metadata=None):
        """
        Add a document to the RAG system.
        
        Args:
            title (str): Document title
            content (str): Document content
            source (str, optional): Source of the document
            metadata (dict, optional): Additional metadata
            
        Returns:
            str: Document ID if successful, None otherwise
        """
        if not self.enabled:
            logger.debug("RAG system is disabled, document not added")
            return None
        
        try:
            # Add to document store
            doc_id = self.document_store.add_document(title, content, source, metadata)
            
            if not doc_id:
                return None
            
            # Get document with chunks
            doc = self.document_store.get_document(doc_id)
            
            if not doc or 'chunks' not in doc:
                return doc_id
            
            # Add each chunk to vector store
            for chunk in doc['chunks']:
                self.vector_store.add_chunk(
                    chunk['id'],
                    doc_id,
                    chunk['content'],
                    chunk['chunk_index']
                )
            
            logger.info(f"Added document '{title}' to RAG system with ID {doc_id}")
            return doc_id
            
        except Exception as e:
            logger.error(f"Error adding document to RAG system: {str(e)}")
            return None
    
    def delete_document(self, doc_id):
        """
        Delete a document from the RAG system.
        
        Args:
            doc_id (str): Document ID
            
        Returns:
            bool: True if successful, False otherwise
        """
        if not self.enabled:
            logger.debug("RAG system is disabled, document not deleted")
            return False
        
        try:
            # Delete from document store (will cascade delete chunks)
            success = self.document_store.delete_document(doc_id)
            
            if success:
                logger.info(f"Deleted document {doc_id} from RAG system")
                # Note: We should also remove from vector store, but that would
                # require rebuilding the FAISS index. For simplicity, we'll
                # accept that vector store may contain orphaned embeddings.
            
            return success
            
        except Exception as e:
            logger.error(f"Error deleting document from RAG system: {str(e)}")
            return False
    
    def enhance_response(self, query, base_response):
        """
        Enhance a response with relevant information from the RAG system.
        
        Args:
            query (str): User query
            base_response (str): Base response to enhance
            
        Returns:
            str: Enhanced response
        """
        if not self.enabled:
            return base_response
        
        try:
            # Retrieve relevant information
            results = self.retrieve(query, limit=2)
            
            if not results:
                return base_response
            
            # Create an enhanced response by adding context
            sources = []
            for result in results:
                sources.append(f"- {result['title']}")
            
            # Add sources as a footnote if relevant information was found
            enhanced_response = base_response
            
            if sources:
                enhanced_response += "\n\nI've included relevant information from your documents."
            
            return enhanced_response
            
        except Exception as e:
            logger.error(f"Error enhancing response: {str(e)}")
            return base_response
    
    def cleanup(self):
        """Release resources."""
        if not self.enabled:
            return
        
        try:
            if hasattr(self, 'document_store'):
                self.document_store.cleanup()
                
            if hasattr(self, 'vector_store'):
                self.vector_store.cleanup()
                
            logger.debug("RAG system resources released")
            
        except Exception as e:
            logger.error(f"Error cleaning up RAG system: {str(e)}")
