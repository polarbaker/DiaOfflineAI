"""
Document Store Module

Manages document storage and retrieval for RAG functionality
"""

import os
import logging
import json
import sqlite3
import time
from pathlib import Path
import uuid

logger = logging.getLogger(__name__)

class DocumentStore:
    """Handles storage and retrieval of documents for RAG."""
    
    def __init__(self, config):
        """
        Initialize the document store.
        
        Args:
            config (dict): Configuration for the document store
        """
        self.config = config
        
        # Get database path
        self.db_path = config.get('database_path')
        if not self.db_path:
            # Use default path
            self.db_path = os.path.join(Path(__file__).parent.parent.parent, 'models', 'rag')
        
        # Ensure database directory exists
        os.makedirs(self.db_path, exist_ok=True)
        
        # Connect to SQLite database
        self.db_file = os.path.join(self.db_path, 'documents.sqlite')
        self.conn = self._connect_db()
        
        # Initialize database schema
        self._init_schema()
        
        logger.info(f"Document store initialized with database at {self.db_file}")
    
    def _connect_db(self):
        """
        Connect to the SQLite database.
        
        Returns:
            sqlite3.Connection: Database connection
        """
        try:
            conn = sqlite3.connect(self.db_file)
            # Enable foreign keys
            conn.execute("PRAGMA foreign_keys = ON")
            return conn
        except sqlite3.Error as e:
            logger.error(f"Error connecting to database: {str(e)}")
            raise
    
    def _init_schema(self):
        """Initialize the database schema if it doesn't exist."""
        try:
            cursor = self.conn.cursor()
            
            # Create documents table
            cursor.execute('''
            CREATE TABLE IF NOT EXISTS documents (
                id TEXT PRIMARY KEY,
                title TEXT,
                source TEXT,
                timestamp INTEGER,
                metadata TEXT
            )
            ''')
            
            # Create chunks table
            cursor.execute('''
            CREATE TABLE IF NOT EXISTS chunks (
                id TEXT PRIMARY KEY,
                document_id TEXT,
                content TEXT,
                chunk_index INTEGER,
                embedding_file TEXT,
                FOREIGN KEY (document_id) REFERENCES documents(id) ON DELETE CASCADE
            )
            ''')
            
            self.conn.commit()
            logger.debug("Database schema initialized")
            
        except sqlite3.Error as e:
            logger.error(f"Error initializing database schema: {str(e)}")
            raise
    
    def add_document(self, title, content, source=None, metadata=None):
        """
        Add a document to the store.
        
        Args:
            title (str): Document title
            content (str): Document content
            source (str, optional): Source of the document
            metadata (dict, optional): Additional metadata
            
        Returns:
            str: Document ID
        """
        try:
            # Generate unique ID
            doc_id = str(uuid.uuid4())
            
            # Current timestamp
            timestamp = int(time.time())
            
            # Convert metadata to JSON
            metadata_json = json.dumps(metadata) if metadata else "{}"
            
            # Insert document
            cursor = self.conn.cursor()
            cursor.execute(
                "INSERT INTO documents (id, title, source, timestamp, metadata) VALUES (?, ?, ?, ?, ?)",
                (doc_id, title, source, timestamp, metadata_json)
            )
            
            # Split content into chunks (simple implementation)
            chunks = self._split_content(content)
            
            # Add chunks
            for i, chunk in enumerate(chunks):
                chunk_id = str(uuid.uuid4())
                embedding_file = f"{chunk_id}.npy"
                
                cursor.execute(
                    "INSERT INTO chunks (id, document_id, content, chunk_index, embedding_file) VALUES (?, ?, ?, ?, ?)",
                    (chunk_id, doc_id, chunk, i, embedding_file)
                )
            
            self.conn.commit()
            logger.info(f"Added document '{title}' with ID {doc_id}")
            
            return doc_id
            
        except Exception as e:
            self.conn.rollback()
            logger.error(f"Error adding document: {str(e)}")
            raise
    
    def _split_content(self, content, max_chunk_size=512):
        """
        Split content into manageable chunks.
        
        Args:
            content (str): Content to split
            max_chunk_size (int, optional): Maximum chunk size in characters
            
        Returns:
            list: List of content chunks
        """
        # Simple splitting by paragraphs and then by size
        paragraphs = content.split('\n\n')
        chunks = []
        current_chunk = ""
        
        for para in paragraphs:
            if len(current_chunk) + len(para) <= max_chunk_size:
                current_chunk += para + "\n\n"
            else:
                if current_chunk:
                    chunks.append(current_chunk.strip())
                current_chunk = para + "\n\n"
        
        if current_chunk:
            chunks.append(current_chunk.strip())
        
        logger.debug(f"Split content into {len(chunks)} chunks")
        return chunks
    
    def get_document(self, doc_id):
        """
        Get a document by ID.
        
        Args:
            doc_id (str): Document ID
            
        Returns:
            dict: Document data
        """
        try:
            cursor = self.conn.cursor()
            cursor.execute(
                "SELECT id, title, source, timestamp, metadata FROM documents WHERE id = ?",
                (doc_id,)
            )
            row = cursor.fetchone()
            
            if not row:
                logger.warning(f"Document with ID {doc_id} not found")
                return None
            
            doc = {
                'id': row[0],
                'title': row[1],
                'source': row[2],
                'timestamp': row[3],
                'metadata': json.loads(row[4])
            }
            
            # Get chunks
            cursor.execute(
                "SELECT id, content, chunk_index FROM chunks WHERE document_id = ? ORDER BY chunk_index",
                (doc_id,)
            )
            chunks = []
            for row in cursor.fetchall():
                chunks.append({
                    'id': row[0],
                    'content': row[1],
                    'chunk_index': row[2]
                })
            
            doc['chunks'] = chunks
            
            return doc
            
        except Exception as e:
            logger.error(f"Error getting document: {str(e)}")
            return None
    
    def search_documents(self, query, limit=5):
        """
        Search for documents (simple text-based search).
        
        Args:
            query (str): Search query
            limit (int, optional): Maximum number of results
            
        Returns:
            list: Matching documents
        """
        try:
            cursor = self.conn.cursor()
            cursor.execute(
                """
                SELECT d.id, d.title, c.content, c.chunk_index 
                FROM documents d
                JOIN chunks c ON d.id = c.document_id
                WHERE c.content LIKE ?
                LIMIT ?
                """,
                (f"%{query}%", limit)
            )
            
            results = []
            for row in cursor.fetchall():
                results.append({
                    'id': row[0],
                    'title': row[1],
                    'content': row[2],
                    'chunk_index': row[3]
                })
            
            logger.debug(f"Found {len(results)} results for query '{query}'")
            return results
            
        except Exception as e:
            logger.error(f"Error searching documents: {str(e)}")
            return []
    
    def delete_document(self, doc_id):
        """
        Delete a document by ID.
        
        Args:
            doc_id (str): Document ID
            
        Returns:
            bool: True if successful, False otherwise
        """
        try:
            cursor = self.conn.cursor()
            cursor.execute("DELETE FROM documents WHERE id = ?", (doc_id,))
            
            if cursor.rowcount > 0:
                self.conn.commit()
                logger.info(f"Deleted document with ID {doc_id}")
                return True
            else:
                logger.warning(f"Document with ID {doc_id} not found for deletion")
                return False
                
        except Exception as e:
            self.conn.rollback()
            logger.error(f"Error deleting document: {str(e)}")
            return False
    
    def cleanup(self):
        """Close database connection."""
        try:
            if hasattr(self, 'conn') and self.conn:
                self.conn.close()
                logger.debug("Document store database connection closed")
        except Exception as e:
            logger.error(f"Error closing database connection: {str(e)}")
