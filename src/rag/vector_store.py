"""
Vector Store Module

Handles embeddings and vector similarity search for RAG functionality
"""

import os
import logging
import numpy as np
from pathlib import Path
import pickle

logger = logging.getLogger(__name__)

class VectorStore:
    """Handles vector embeddings and similarity search for RAG."""
    
    def __init__(self, config):
        """
        Initialize the vector store.
        
        Args:
            config (dict): Configuration for the vector store
        """
        self.config = config
        
        # Get database path
        self.db_path = config.get('database_path')
        if not self.db_path:
            # Use default path
            self.db_path = os.path.join(Path(__file__).parent.parent.parent, 'models', 'rag')
        
        # Path to embeddings
        self.embeddings_path = os.path.join(self.db_path, 'embeddings')
        os.makedirs(self.embeddings_path, exist_ok=True)
        
        # Get embedding model
        self.embedding_model_name = config.get('embedding_model', 'all-MiniLM-L6-v2')
        
        # Initialize embedding model and index
        self._init_embedding_model()
        self._init_faiss_index()
        
        logger.info(f"Vector store initialized with {self.embedding_model_name} embedding model")
    
    def _init_embedding_model(self):
        """Initialize the embedding model."""
        try:
            # Try to import sentence-transformers
            from sentence_transformers import SentenceTransformer
            
            self.embedding_model = SentenceTransformer(self.embedding_model_name)
            logger.info(f"Loaded embedding model: {self.embedding_model_name}")
            
        except ImportError:
            logger.warning("sentence-transformers not installed. Install with: pip install sentence-transformers")
            self.embedding_model = None
            
        except Exception as e:
            logger.error(f"Error loading embedding model: {str(e)}")
            self.embedding_model = None
    
    def _init_faiss_index(self):
        """Initialize FAISS index for similarity search."""
        try:
            # Try to import FAISS
            import faiss
            
            # Load index if it exists
            index_path = os.path.join(self.embeddings_path, 'faiss_index.pkl')
            metadata_path = os.path.join(self.embeddings_path, 'faiss_metadata.pkl')
            
            if os.path.exists(index_path) and os.path.exists(metadata_path):
                # Load existing index
                with open(index_path, 'rb') as f:
                    self.index = pickle.load(f)
                    
                with open(metadata_path, 'rb') as f:
                    self.chunk_metadata = pickle.load(f)
                    
                logger.info(f"Loaded existing FAISS index with {self.index.ntotal} vectors")
                
            else:
                # Create new index
                # We'll use L2 distance as the metric (smaller is more similar)
                self.dimension = 384  # Default for all-MiniLM-L6-v2
                self.index = faiss.IndexFlatL2(self.dimension)
                self.chunk_metadata = []
                
                logger.info(f"Created new FAISS index with dimension {self.dimension}")
        
        except ImportError:
            logger.warning("FAISS not installed. Install with: pip install faiss-cpu")
            self.index = None
            self.chunk_metadata = []
            
        except Exception as e:
            logger.error(f"Error initializing FAISS index: {str(e)}")
            self.index = None
            self.chunk_metadata = []
    
    def embed_text(self, text):
        """
        Generate embeddings for text.
        
        Args:
            text (str): Text to embed
            
        Returns:
            numpy.ndarray: Embedding vector
        """
        if not self.embedding_model:
            logger.error("Embedding model not initialized")
            return None
        
        try:
            embedding = self.embedding_model.encode(text)
            return embedding
            
        except Exception as e:
            logger.error(f"Error generating embedding: {str(e)}")
            return None
    
    def add_chunk(self, chunk_id, document_id, content, chunk_index):
        """
        Add a chunk to the vector store.
        
        Args:
            chunk_id (str): Chunk ID
            document_id (str): Document ID
            content (str): Chunk content
            chunk_index (int): Chunk index
            
        Returns:
            bool: True if successful, False otherwise
        """
        if not self.embedding_model or not self.index:
            logger.error("Vector store not properly initialized")
            return False
        
        try:
            # Generate embedding
            embedding = self.embed_text(content)
            
            if embedding is None:
                return False
            
            # Save embedding to file
            embedding_file = os.path.join(self.embeddings_path, f"{chunk_id}.npy")
            np.save(embedding_file, embedding)
            
            # Add to FAISS index
            embedding = embedding.reshape(1, -1).astype(np.float32)
            faiss_id = self.index.ntotal  # Get current number of vectors as ID
            self.index.add(embedding)
            
            # Store metadata
            self.chunk_metadata.append({
                'faiss_id': faiss_id,
                'chunk_id': chunk_id,
                'document_id': document_id,
                'chunk_index': chunk_index
            })
            
            # Save index and metadata
            self._save_index()
            
            logger.debug(f"Added chunk {chunk_id} to vector store")
            return True
            
        except Exception as e:
            logger.error(f"Error adding chunk to vector store: {str(e)}")
            return False
    
    def search(self, query, limit=5):
        """
        Search for similar chunks using vector similarity.
        
        Args:
            query (str): Query text
            limit (int, optional): Maximum number of results
            
        Returns:
            list: Metadata for similar chunks
        """
        if not self.embedding_model or not self.index:
            logger.error("Vector store not properly initialized")
            return []
        
        try:
            # Generate embedding
            query_embedding = self.embed_text(query)
            
            if query_embedding is None:
                return []
            
            # Reshape for FAISS
            query_embedding = query_embedding.reshape(1, -1).astype(np.float32)
            
            # Search index
            distances, indices = self.index.search(query_embedding, limit)
            
            # Get metadata for results
            results = []
            for i, idx in enumerate(indices[0]):
                if idx != -1 and idx < len(self.chunk_metadata):
                    result = self.chunk_metadata[idx].copy()
                    result['score'] = float(1.0 / (1.0 + distances[0][i]))  # Convert distance to similarity score
                    results.append(result)
            
            logger.debug(f"Found {len(results)} similar chunks for query")
            return results
            
        except Exception as e:
            logger.error(f"Error searching vector store: {str(e)}")
            return []
    
    def _save_index(self):
        """Save FAISS index and metadata to disk."""
        try:
            index_path = os.path.join(self.embeddings_path, 'faiss_index.pkl')
            metadata_path = os.path.join(self.embeddings_path, 'faiss_metadata.pkl')
            
            with open(index_path, 'wb') as f:
                pickle.dump(self.index, f)
                
            with open(metadata_path, 'wb') as f:
                pickle.dump(self.chunk_metadata, f)
                
            logger.debug("Saved FAISS index and metadata")
            
        except Exception as e:
            logger.error(f"Error saving FAISS index: {str(e)}")
    
    def cleanup(self):
        """Release resources."""
        logger.debug("Vector store resources released")
