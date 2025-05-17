#!/bin/bash
#
# Dia Assistant Wikipedia Setup Script
# This script downloads and processes Wikipedia content for offline use

set -e

# ANSI color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Paths
WIKI_PATH="/mnt/nvme/dia/wikipedia"
RAW_PATH="${WIKI_PATH}/raw"
PROCESSED_PATH="${WIKI_PATH}/processed"
VECTORS_PATH="${WIKI_PATH}/vectors"
VENV_PATH="/opt/dia/venv"

# Function to print section headers
print_header() {
    echo -e "\n${BLUE}===== $1 =====${NC}\n"
}

# Function to print success messages
print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

# Function to print error messages and exit
print_error() {
    echo -e "${RED}✗ ERROR: $1${NC}"
    exit 1
}

# Function to print warning messages
print_warning() {
    echo -e "${YELLOW}⚠ WARNING: $1${NC}"
}

# Display welcome message
print_header "Dia Assistant Wikipedia Setup"
echo "This script will download and process Wikipedia for offline use."
echo "Warning: This process requires significant disk space (~80GB) and will take several hours."
echo ""
echo "Choose Wikipedia download option:"
echo "1) English Wikipedia - Small Subset (recommended for testing, ~5GB)"
echo "2) English Wikipedia - Selected Topics (useful subset, ~20GB)"
echo "3) Full English Wikipedia (complete, ~80GB)"
echo "4) Quit"
read -p "Enter option [1-4]: " option

# Create directories
mkdir -p "${RAW_PATH}" "${PROCESSED_PATH}" "${VECTORS_PATH}"

# Activate Python environment
source "${VENV_PATH}/bin/activate"

# Install required packages
print_header "Installing Required Packages"
pip install wikiextractor sentence-transformers faiss-cpu tqdm

# Download Wikipedia based on option
case $option in
    1)
        print_header "Downloading English Wikipedia - Small Subset"
        cd "${RAW_PATH}"
        wget -O enwiki-latest-pages-articles1.xml-p1p41242.bz2 https://dumps.wikimedia.org/enwiki/latest/enwiki-latest-pages-articles1.xml-p1p41242.bz2
        print_success "Downloaded small Wikipedia subset"
        WIKI_FILE="enwiki-latest-pages-articles1.xml-p1p41242.bz2"
        ;;
    2)
        print_header "Downloading English Wikipedia - Selected Topics"
        cd "${RAW_PATH}"
        for i in {1..5}; do
            wget -O "enwiki-latest-pages-articles${i}.xml-p*.bz2" "https://dumps.wikimedia.org/enwiki/latest/enwiki-latest-pages-articles${i}.xml-p*.bz2"
        done
        print_success "Downloaded selected Wikipedia topics"
        WIKI_FILE="enwiki-latest-pages-articles*.xml-p*.bz2"
        ;;
    3)
        print_header "Downloading Full English Wikipedia"
        cd "${RAW_PATH}"
        wget -O enwiki-latest-pages-articles.xml.bz2 https://dumps.wikimedia.org/enwiki/latest/enwiki-latest-pages-articles.xml.bz2
        print_success "Downloaded full Wikipedia"
        WIKI_FILE="enwiki-latest-pages-articles.xml.bz2"
        ;;
    4)
        echo "Exiting without downloading."
        exit 0
        ;;
    *)
        print_error "Invalid option"
        ;;
esac

# Process Wikipedia
print_header "Processing Wikipedia"
cd "${WIKI_PATH}"
echo "This will take several hours depending on your chosen Wikipedia size..."
python3 -m wikiextractor.WikiExtractor "${RAW_PATH}/${WIKI_FILE}" --output "${PROCESSED_PATH}" --json

# Create a Python script to process Wikipedia into vectors
cat > process_wiki.py << 'EOF'
#!/usr/bin/env python3
import os
import json
import faiss
import numpy as np
import sqlite3
from tqdm import tqdm
from sentence_transformers import SentenceTransformer
import logging
import sys
import glob

# Set up logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler("wikipedia_processing.log"),
        logging.StreamHandler(sys.stdout)
    ]
)
logger = logging.getLogger("wikipedia_processing")

# Paths
PROCESSED_PATH = "/mnt/nvme/dia/wikipedia/processed"
VECTORS_PATH = "/mnt/nvme/dia/wikipedia/vectors"
DB_PATH = os.path.join(VECTORS_PATH, "wikipedia.db")
INDEX_PATH = os.path.join(VECTORS_PATH, "wikipedia.index")
METADATA_PATH = os.path.join(VECTORS_PATH, "metadata.json")

# Initialize the embedding model
logger.info("Loading embedding model...")
model = SentenceTransformer('all-MiniLM-L6-v2')
embedding_size = model.get_sentence_embedding_dimension()

# Initialize FAISS index
logger.info(f"Creating FAISS index with dimension {embedding_size}")
index = faiss.IndexFlatL2(embedding_size)

# Initialize SQLite database
logger.info(f"Creating SQLite database at {DB_PATH}")
conn = sqlite3.connect(DB_PATH)
cursor = conn.cursor()
cursor.execute('''
CREATE TABLE IF NOT EXISTS articles (
    id INTEGER PRIMARY KEY,
    title TEXT,
    content TEXT,
    url TEXT
)
''')
cursor.execute('''
CREATE TABLE IF NOT EXISTS chunks (
    id INTEGER PRIMARY KEY,
    article_id INTEGER,
    content TEXT,
    embedding_id INTEGER,
    FOREIGN KEY (article_id) REFERENCES articles (id)
)
''')
conn.commit()

# Function to clean and chunk text
def chunk_text(text, max_length=512):
    # Simple chunking by paragraph then by size
    paragraphs = text.split('\n\n')
    chunks = []
    current_chunk = ""
    
    for para in paragraphs:
        para = para.strip()
        if not para:
            continue
            
        if len(current_chunk) + len(para) <= max_length:
            current_chunk += para + "\n\n"
        else:
            if current_chunk:
                chunks.append(current_chunk.strip())
            current_chunk = para + "\n\n"
    
    if current_chunk:
        chunks.append(current_chunk.strip())
        
    return chunks

# Process Wikipedia files
def process_wikipedia_files():
    article_id = 0
    embedding_id = 0
    metadata = {"articles": 0, "chunks": 0}
    
    # Find all files in the processed directory
    wiki_files = []
    for subdir in os.listdir(PROCESSED_PATH):
        subdir_path = os.path.join(PROCESSED_PATH, subdir)
        if os.path.isdir(subdir_path):
            for filename in glob.glob(os.path.join(subdir_path, "wiki_*")):
                wiki_files.append(filename)
    
    logger.info(f"Found {len(wiki_files)} files to process")
    
    # Process each file
    for file_path in tqdm(wiki_files):
        with open(file_path, 'r', encoding='utf-8') as file:
            for line in file:
                try:
                    # Parse the JSON line
                    article = json.loads(line)
                    title = article['title']
                    content = article['text']
                    url = f"https://en.wikipedia.org/wiki/{title.replace(' ', '_')}"
                    
                    # Skip very short articles
                    if len(content) < 100:
                        continue
                    
                    # Insert article into database
                    cursor.execute(
                        "INSERT INTO articles (id, title, content, url) VALUES (?, ?, ?, ?)",
                        (article_id, title, content, url)
                    )
                    
                    # Chunk the article
                    chunks = chunk_text(content)
                    
                    # Process each chunk
                    if chunks:
                        chunk_embeddings = model.encode(chunks)
                        
                        for i, (chunk, embedding) in enumerate(zip(chunks, chunk_embeddings)):
                            # Add to FAISS index
                            embedding_np = np.array([embedding], dtype=np.float32)
                            index.add(embedding_np)
                            
                            # Add to database
                            cursor.execute(
                                "INSERT INTO chunks (id, article_id, content, embedding_id) VALUES (?, ?, ?, ?)",
                                (embedding_id, article_id, chunk, embedding_id)
                            )
                            
                            embedding_id += 1
                    
                    # Commit every 100 articles
                    if article_id % 100 == 0:
                        conn.commit()
                        
                    article_id += 1
                    metadata["articles"] = article_id
                    metadata["chunks"] = embedding_id
                    
                    # Show progress every 1000 articles
                    if article_id % 1000 == 0:
                        logger.info(f"Processed {article_id} articles, {embedding_id} chunks")
                        
                except Exception as e:
                    logger.error(f"Error processing article: {e}")
    
    # Final commit
    conn.commit()
    
    # Save FAISS index
    logger.info(f"Saving FAISS index with {index.ntotal} vectors")
    faiss.write_index(index, INDEX_PATH)
    
    # Save metadata
    with open(METADATA_PATH, 'w') as f:
        json.dump(metadata, f)
    
    logger.info(f"Wikipedia processing complete. Processed {article_id} articles and {embedding_id} chunks.")
    
    return metadata

if __name__ == "__main__":
    try:
        os.makedirs(VECTORS_PATH, exist_ok=True)
        metadata = process_wikipedia_files()
        print(f"Processing complete! Added {metadata['articles']} articles and {metadata['chunks']} chunks to the database.")
    except Exception as e:
        logger.error(f"Fatal error: {e}")
        raise
    finally:
        if 'conn' in locals():
            conn.close()
EOF

chmod +x process_wiki.py

# Run the processing script
print_header "Creating Vector Database"
echo "This will take several hours depending on the size of Wikipedia..."
echo "You can leave this running overnight."
echo ""
echo "The script will:"
echo "1. Extract text from Wikipedia XML"
echo "2. Split articles into searchable chunks"
echo "3. Create embeddings for each chunk"
echo "4. Build a search index for fast retrieval"
echo ""
read -p "Start processing now? (y/n): " proceed

if [[ "$proceed" == "y" || "$proceed" == "Y" ]]; then
    python3 process_wiki.py
    print_success "Wikipedia processing complete!"
    
    # Create a symlink to the database
    ln -sf "${VECTORS_PATH}/wikipedia.db" "/opt/dia/models/rag/wikipedia.db"
    ln -sf "${VECTORS_PATH}/wikipedia.index" "/opt/dia/models/rag/wikipedia.index"
    
    print_header "Setup Complete!"
    echo "Wikipedia has been processed and is ready for use with Dia."
    echo "When your microphone and speakers arrive, Dia will be able to answer questions using this offline Wikipedia data."
else
    print_warning "Processing cancelled. You can run this script again later."
fi

# Exit message
echo ""
echo "You can run the following command to start processing later:"
echo "cd ${WIKI_PATH} && python3 process_wiki.py"
